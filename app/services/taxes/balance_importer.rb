module Taxes
  class BalanceImporter
    # Columna 1 → nivel jerárquico (Clase/Grupo/Cuenta/SubCuenta/Auxiliar)
    # Columna 2 → código contable (numérico)
    # Columna 3 → nombre de la cuenta
    # Columnas 4-7 → saldo inicial, débito, crédito, saldo final
    EXPECTED_COLUMNS = 7

    # Cuántas filas de metadatos puede tener el encabezado antes de los headers reales
    MAX_HEADER_SCAN_ROWS = 15

    # Palabras clave para detectar la fila de encabezados
    HEADER_KEYWORDS = %w[nivel codigo código cuenta saldo debito crédito].freeze

    Result = Struct.new(:success, :imported, :skipped, :errors, :meta, keyword_init: true)

    def initialize(file, period)
      @file    = file
      @period  = period
      @errors  = []
      @imported = 0
      @skipped  = 0
      @meta     = {}
    end

    def call
      spreadsheet = open_spreadsheet
      sheet = spreadsheet.sheet(0)

      # 1. Detectar fila de encabezados y extraer metadatos previos
      header_row_idx = find_header_row(sheet)
      if header_row_idx.nil?
        return Result.new(
          success: false, imported: 0, skipped: 0,
          errors: ["No se encontró la fila de encabezados. " \
                   "Se esperan columnas: Nivel, Código contable, Cuenta contable, " \
                   "Saldo inicial, Débito, Crédito, Saldo final"],
          meta: {}
        )
      end

      extract_metadata(sheet, header_row_idx)
      update_period_metadata

      # 2. Mapear columnas a partir del encabezado detectado
      headers = normalize_row(sheet.row(header_row_idx))
      mapping = build_column_mapping(headers)

      unless mapping_valid?(mapping)
        missing = %i[account_code closing_balance] - mapping.keys
        return Result.new(
          success: false, imported: 0, skipped: 0,
          errors: ["Columnas obligatorias no encontradas: #{missing.join(', ')}. " \
                   "Encabezados detectados en fila #{header_row_idx}: #{headers.inspect}"],
          meta: @meta
        )
      end

      # 3. Importar SOLO filas de nivel Auxiliar
      first_data_row = header_row_idx + 1
      (first_data_row..sheet.last_row).each do |i|
        row = sheet.row(i)
        next if row.compact.empty?

        nivel = row[mapping[:account_type]].to_s.strip
        # Saltar todo lo que no sea Auxiliar (Clase, Grupo, Cuenta, SubCuenta)
        next unless nivel.downcase == "auxiliar"

        raw_code = row[mapping[:account_code]]
        # Los códigos numéricos llegan como Float (1101.0); convertir a entero antes de stringify
        code = raw_code.is_a?(Numeric) ? raw_code.to_i.to_s : raw_code.to_s.strip
        next if code.blank?

        attrs = {
          account_type:          nivel,
          account_code:          code,
          account_name:          row[mapping[:account_name]].to_s.strip,
          account_class:         code[0],
          opening_balance_cents: to_cents(row[mapping[:opening_balance]]),
          debit_cents:           to_cents(row[mapping[:debit]]),
          credit_cents:          to_cents(row[mapping[:credit]]),
          closing_balance_cents: to_cents(row[mapping[:closing_balance]]),
          review_status:         "pending",
          reconciliation_period: @period
        }

        item = ReconciliationItem.find_or_initialize_by(
          reconciliation_period: @period,
          account_code:          code
        )

        if item.new_record?
          item.assign_attributes(attrs)
          if item.save(validate: false)
            @imported += 1
          else
            @errors << "Fila #{i} (#{code}): #{item.errors.full_messages.join(', ')}"
            @skipped += 1
          end
        else
          # Cuenta ya existe — actualizar saldos, conservar conciliación manual
          item.update_columns(
            account_type:          attrs[:account_type],
            account_name:          attrs[:account_name],
            opening_balance_cents: attrs[:opening_balance_cents],
            debit_cents:           attrs[:debit_cents],
            credit_cents:          attrs[:credit_cents],
            closing_balance_cents: attrs[:closing_balance_cents],
            updated_at:            Time.current
          )
          @skipped += 1
        end
      end

      @period.update!(status: "in_review") if @period.status == "draft" && @imported > 0

      Result.new(
        success: @errors.empty?,
        imported: @imported,
        skipped: @skipped,
        errors: @errors,
        meta: @meta
      )
    rescue => e
      Result.new(success: false, imported: 0, skipped: 0, errors: [e.message], meta: @meta)
    end

    private

    # ── Detección automática del encabezado ────────────────────────────────

    def find_header_row(sheet)
      last_scan = [MAX_HEADER_SCAN_ROWS, sheet.last_row].min
      (1..last_scan).each do |i|
        row = sheet.row(i)
        next if row.compact.empty?
        normalized = row.map { |c| normalize_str(c.to_s) }
        # La fila de encabezados debe contener al menos 2 palabras clave
        matches = HEADER_KEYWORDS.count { |kw| normalized.any? { |h| h.include?(kw) } }
        return i if matches >= 2
      end
      nil
    end

    # ── Extracción de metadatos (filas previas al encabezado) ──────────────

    def extract_metadata(sheet, header_row_idx)
      lines = (1...header_row_idx).map { |i| sheet.row(i).compact.first.to_s.strip }.reject(&:blank?)
      @meta[:raw_lines] = lines

      lines.each do |line|
        # NIT: contiene guión al final y dígito de verificación
        if line.match?(/\d{3}[.\s]?\d{3}[.\s]?\d{3}[-]?\d/)
          @meta[:nit] = line
        # Fecha de período
        elsif line.match?(/\d{2}\/\d{2}\/\d{4}/)
          @meta[:period_range] = line
        # Nombre empresa (línea que no es título del reporte)
        elsif line.length > 5 && !line.downcase.include?("balance") &&
              !line.downcase.include?("prueba") && @meta[:company_name].nil?
          @meta[:company_name] = line
        end
      end
    end

    def update_period_metadata
      updates = {}
      updates[:company_name] = @meta[:company_name] if @meta[:company_name].present? && @period.company_name.blank?
      updates[:company_nit]  = @meta[:nit]          if @meta[:nit].present?          && @period.company_nit.blank?
      @period.update_columns(updates.merge(updated_at: Time.current)) if updates.any?
    end

    # ── Mapeo de columnas ──────────────────────────────────────────────────

    # Regla de mapeo: columna esperada → palabras clave normalizadas
    # Regla clave: "Código contable" tiene "codigo"; "Cuenta contable" tiene "cuenta".
    # Nunca usar "contable" como keyword para account_name — es ambiguo con la columna del código.
    COLUMN_MAP_RULES = {
      account_type:    %w[nivel],
      account_code:    %w[codigo],     # "Código contable" → match "codigo"
      account_name:    %w[cuenta nombre descripcion],  # "Cuenta contable" → match "cuenta"
      opening_balance: %w[inicial],
      debit:           %w[debito debe],
      credit:          %w[credito haber],
      closing_balance: %w[final]
    }.freeze

    def build_column_mapping(headers)
      COLUMN_MAP_RULES.each_with_object({}) do |(field, keywords), map|
        idx = headers.index { |h| keywords.any? { |kw| h.include?(kw) } }
        map[field] = idx if idx
      end
    end

    def mapping_valid?(mapping)
      %i[account_code closing_balance].all? { |k| mapping.key?(k) }
    end

    # ── Normalización ──────────────────────────────────────────────────────

    def normalize_str(str)
      str.to_s.downcase.strip
         .gsub(/[áàä]/, "a").gsub(/[éèë]/, "e")
         .gsub(/[íìï]/, "i").gsub(/[óòö]/, "o")
         .gsub(/[úùü]/, "u")
         .gsub(/[^a-z0-9\s]/, " ")
         .gsub(/\s+/, " ").strip
    end

    def normalize_row(row)
      row.map { |h| normalize_str(h.to_s) }
    end

    def to_cents(val)
      return 0 if val.nil? || val.to_s.strip.empty?
      (val.to_f * 100).round
    end

    # ── Apertura del archivo ───────────────────────────────────────────────

    def open_spreadsheet
      path = @file.respond_to?(:path) ? @file.path : @file.to_s
      ext  = detect_extension
      Roo::Spreadsheet.open(path, extension: ext)
    end

    def detect_extension
      name = @file.respond_to?(:original_filename) ? @file.original_filename.to_s : @file.to_s
      ext  = File.extname(name).downcase.delete(".")
      %w[xlsx xls ods].include?(ext) ? ext.to_sym : :xlsx
    end
  end
end
