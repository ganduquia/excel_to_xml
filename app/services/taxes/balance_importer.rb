module Taxes
  class BalanceImporter
    # Aliases tolerantes a variaciones de nombre de columna del Excel
    COLUMN_ALIASES = {
      account_type:    %w[tipo_de_cuenta tipo_cuenta tipo clase],
      account_code:    %w[cuenta_contable cuenta codigo],
      account_name:    %w[nombre nombre_de_la_cuenta descripcion],
      opening_balance: %w[saldo_inicial si],
      debit:           %w[debito debe],
      credit:          %w[credito haber],
      closing_balance: %w[saldo_final sf]
    }.freeze

    Result = Struct.new(:success, :imported, :skipped, :errors, keyword_init: true)

    def initialize(file, period)
      @file    = file
      @period  = period
      @errors  = []
      @imported = 0
      @skipped  = 0
    end

    def call
      spreadsheet = open_spreadsheet
      sheet = spreadsheet.sheet(0)

      raw_headers = sheet.row(1)
      headers = normalize_headers(raw_headers)
      mapping = map_columns(headers)

      unless mapping_complete?(mapping)
        missing = required_columns - mapping.keys
        return Result.new(
          success: false, imported: 0, skipped: 0,
          errors: ["Columnas requeridas no encontradas: #{missing.join(', ')}. " \
                   "Encabezados detectados: #{raw_headers.compact.join(', ')}"]
        )
      end

      (2..sheet.last_row).each do |i|
        row = sheet.row(i)
        next if row.compact.empty?

        code = row[mapping[:account_code]].to_s.strip
        next if code.blank?

        attrs = extract_attrs(row, mapping)
        item = ReconciliationItem.find_or_initialize_by(
          reconciliation_period: @period,
          account_code: code
        )

        if item.new_record?
          item.assign_attributes(attrs)
          item.account_class = code[0]
          item.review_status = "pending"
          # save(validate: false) porque has_fiscal_effect es nil y eso dispara validaciones de ajuste
          if item.save(validate: false)
            @imported += 1
          else
            @errors << "Fila #{i}: #{item.errors.full_messages.join(', ')}"
            @skipped += 1
          end
        else
          # Cuenta ya existe; actualizar saldos pero preservar conciliación manual
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

      @period.update!(status: "in_review") if @period.draft? && @imported > 0

      Result.new(success: @errors.empty?, imported: @imported, skipped: @skipped, errors: @errors)
    rescue => e
      Result.new(success: false, imported: 0, skipped: 0, errors: [e.message])
    end

    private

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

    def normalize(str)
      str.to_s.downcase.strip
         .gsub(/\s+/, "_")
         .gsub(/[áàä]/, "a").gsub(/[éèë]/, "e")
         .gsub(/[íìï]/, "i").gsub(/[óòö]/, "o")
         .gsub(/[úùü]/, "u")
         .gsub(/[^a-z0-9_]/, "")
    end

    def normalize_headers(row)
      row.map { |h| normalize(h.to_s) }
    end

    def map_columns(headers)
      COLUMN_ALIASES.each_with_object({}) do |(field, aliases), map|
        idx = headers.index { |h| aliases.any? { |a| h.include?(a) } }
        map[field] = idx if idx
      end
    end

    def required_columns
      %i[account_code closing_balance]
    end

    def mapping_complete?(mapping)
      required_columns.all? { |k| mapping.key?(k) }
    end

    def extract_attrs(row, m)
      {
        account_type:          row[m[:account_type]].to_s.strip,
        account_name:          row[m[:account_name]].to_s.strip,
        opening_balance_cents: to_cents(row[m[:opening_balance]]),
        debit_cents:           to_cents(row[m[:debit]]),
        credit_cents:          to_cents(row[m[:credit]]),
        closing_balance_cents: to_cents(row[m[:closing_balance]])
      }
    end

    def to_cents(val)
      return 0 if val.nil? || val.to_s.strip.empty?
      (val.to_f * 100).round
    end
  end
end
