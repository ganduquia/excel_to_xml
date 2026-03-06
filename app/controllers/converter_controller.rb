class ConverterController < ApplicationController
  def index
  end

  def upload
    unless params[:excel_file].present?
      flash[:alert] = "Por favor selecciona un archivo Excel."
      return redirect_to root_path
    end

    file = params[:excel_file]
    ext  = File.extname(file.original_filename).downcase

    unless [".xlsx", ".xls"].include?(ext)
      flash[:alert] = "Solo se permiten archivos .xlsx o .xls"
      return redirect_to root_path
    end

    begin
      xml_filename = "#{File.basename(file.original_filename, ext)}_#{Time.now.to_i}.xml"
      xml_path     = Rails.root.join("tmp", xml_filename)

      if ext == ".xlsx"
        stream_xlsx_to_xml(file.path, file.original_filename, xml_path)
      else
        spreadsheet = Roo::Excel.new(file.path)
        write_roo_to_xml(spreadsheet, file.original_filename, xml_path)
      end

      # XSD validation (opcional)
      xsd_errors = []
      if params[:xsd_file].present?
        xsd_file = params[:xsd_file]
        unless File.extname(xsd_file.original_filename).downcase == ".xsd"
          flash[:alert] = "El archivo de schema debe tener extensión .xsd"
          return redirect_to root_path
        end
        xml_doc    = Nokogiri::XML(File.read(xml_path))
        xsd_doc    = Nokogiri::XML::Schema(File.read(xsd_file.path))
        xsd_errors = xsd_doc.validate(xml_doc)
      end

      if xsd_errors.any?
        # Guardar errores en archivo temporal (evita CookieOverflow)
        errors_data = xsd_errors.first(200).map { |e| { line: e.line, message: e.message } }
        errors_file = "#{xml_filename}_errors.json"
        File.write(Rails.root.join("tmp", errors_file), errors_data.to_json)
        session[:xsd_errors_file] = errors_file
        session[:xsd_used]        = true
      else
        session[:xsd_errors_file] = nil
        session[:xsd_used]        = params[:xsd_file].present?
        flash[:notice]            = params[:xsd_file].present? ? "Conversión exitosa. XML válido según el XSD." : "Conversión exitosa."
      end

      redirect_to converter_download_path(filename: xml_filename)

    rescue => e
      flash[:alert] = "Error: #{e.message}"
      redirect_to root_path
    end
  end

  def download
    filename = params[:filename].gsub(/[^a-zA-Z0-9_\-.]/, "")
    path     = Rails.root.join("tmp", filename)

    errors_file = session.delete(:xsd_errors_file)
    xsd_used    = session.delete(:xsd_used)
    xsd_errors  = []

    if errors_file
      errors_path = Rails.root.join("tmp", errors_file)
      if File.exist?(errors_path)
        xsd_errors = JSON.parse(File.read(errors_path), symbolize_names: true)
        File.delete(errors_path)
      end
    end

    if xsd_errors.any?
      @xsd_errors   = xsd_errors
      @xml_filename = filename
      @xsd_valid    = false
      @xsd_used     = true
      render :validation_result
    elsif File.exist?(path)
      if params[:get_file]
        send_file path,
                  filename:    filename,
                  type:        "application/xml",
                  disposition: "attachment"
      else
        @xml_filename = filename
        @xsd_valid    = true
        @xsd_used     = xsd_used
        render :validation_result
      end
    else
      flash[:alert] = "Archivo no encontrado."
      redirect_to root_path
    end
  end

  private

  # Streaming para .xlsx — eficiente con 75k+ filas
  def stream_xlsx_to_xml(file_path, original_filename, xml_path)
    workbook = Creek::Book.new(file_path, check_file_extension: false)

    File.open(xml_path, "w") do |f|
      f.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
      f.write("<workbook source_file=\"#{CGI.escapeHTML(original_filename)}\" ")
      f.write("generated_at=\"#{Time.now.iso8601}\">\n")

      workbook.sheets.each do |sheet|
        f.write("  <sheet name=\"#{CGI.escapeHTML(sheet.name)}\">\n")
        headers = nil
        row_number = 0

        sheet.rows.each do |row|
          values = row.values

          if headers.nil?
            headers = values.map { |h| sanitize_tag(h.to_s) }
            next
          end

          next if values.all?(&:nil?) || values.all? { |v| v.to_s.strip.empty? }

          row_number += 1
          f.write("    <row number=\"#{row_number}\">\n")
          headers.each_with_index do |header, i|
            tag   = header.empty? ? "column_#{i + 1}" : header
            value = CGI.escapeHTML(values[i].to_s)
            f.write("      <#{tag}>#{value}</#{tag}>\n")
          end
          f.write("    </row>\n")
        end

        f.write("  </sheet>\n")
      end

      f.write("</workbook>\n")
    end
  end

  # Roo para .xls (formato antiguo)
  def write_roo_to_xml(spreadsheet, original_filename, xml_path)
    File.open(xml_path, "w") do |f|
      f.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
      f.write("<workbook source_file=\"#{CGI.escapeHTML(original_filename)}\" ")
      f.write("generated_at=\"#{Time.now.iso8601}\">\n")

      spreadsheet.sheets.each do |sheet_name|
        spreadsheet.default_sheet = sheet_name
        headers = spreadsheet.row(1).map { |h| sanitize_tag(h.to_s) }

        f.write("  <sheet name=\"#{CGI.escapeHTML(sheet_name)}\">\n")

        (2..spreadsheet.last_row).each do |row_num|
          row = spreadsheet.row(row_num)
          next if row.all?(&:nil?)

          f.write("    <row number=\"#{row_num - 1}\">\n")
          headers.each_with_index do |header, i|
            tag   = header.empty? ? "column_#{i + 1}" : header
            value = CGI.escapeHTML(row[i].to_s)
            f.write("      <#{tag}>#{value}</#{tag}>\n")
          end
          f.write("    </row>\n")
        end

        f.write("  </sheet>\n")
      end

      f.write("</workbook>\n")
    end
  end

  def sanitize_tag(str)
    str = str.strip.gsub(/\s+/, "_").gsub(/[^a-zA-Z0-9_\-]/, "")
    str = "_#{str}" if str.match?(/\A\d/)
    str.empty? ? "campo" : str
  end
end
