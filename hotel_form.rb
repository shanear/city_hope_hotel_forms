require 'pdf_forms'
require 'csv'
require 'active_support/all'
require 'dropbox_api'

Time.zone = "Pacific Time (US & Canada)"

class CityHopeHotelForm
  RESIDENTS_CSV_PATH = "./tmp/residents.csv"

  attr_accessor :date

  def initialize(date = Time.zone.now)
    @date = date
  end

  def generate_daily_log!
    pdftk.fill_form(
      "./files/daily-log-fillable.pdf",
      "./tmp/#{daily_log_filename}",
      daily_form_fields_from_csv_data(csv_residents_data)
    )

    upload_daily_log!(daily_log_filename)
  end

  def generate_weekly_report!
    pdftk.fill_form(
      "./files/weekly-report-fillable.pdf",
      "./tmp/#{weekly_report_filename}",
      weekly_report_fields
    )

    upload_weekly_report!(weekly_report_filename)
  end

  private

  def fetch_csv_file!
    dropbox.download("/residents.csv") do |content|
      f = File.new(RESIDENTS_CSV_PATH, "w")
      f.write(content)
      f.close 
    end
  end

  def upload_daily_log!(filename)
    content = IO.read("./tmp/#{filename}")
    dropbox.upload("/daily-logs/#{filename}", content, mode: :overwrite)
  end

  def upload_weekly_report!(filename)
    content = IO.read("./tmp/#{filename}")
    dropbox.upload("/weekly-reports/#{filename}", content, mode: :overwrite)
  end

  def daily_log_filename
    date.strftime("%Y-%m-%d-daily-log.pdf")    
  end

  def weekly_report_filename
    date_of_posting.strftime("%Y-%m-%d-weekly-report.pdf")    
  end

  def date_of_posting
    @date_of_posting ||= date.beginning_of_week
  end

  def weekly_report_fields
    starting_date = date_of_posting - 7.days

    initial_fields = {
      "week-of" => starting_date.strftime("%m/%d/%Y"),
      "date-of-posting" => date_of_posting.strftime("%m/%d/%Y")
    }

    days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

    days.each_with_index.inject(initial_fields) do |fields, (day, i)|
      fields["#{day}-date"] = (starting_date + i.days).strftime("%m/%d/%Y")
      fields
    end
  end

  def daily_form_fields_from_csv_data(residents_data)
    initial_fields = {
      "hotel-address" => "649 Jones St.",
      "date" => date.strftime("%m/%d/%Y")
    }

    residents_data.each_with_index.inject(initial_fields) do |fields, ((room_number, occupant_name), i)|
      fields["occupant-name-#{i}"] = occupant_name
      fields["room-number-#{i}"] = room_number
      fields["is-residential-#{i}"] = "Yes"
      fields["is-tourist-#{i}"] = "No"
      fields["guest-room-vacant-#{i}"] = occupant_name && !occupant_name.strip.empty? ? "No" : "Yes"

      fields
    end
  end

  def csv_residents_data
    fetch_csv_file! 
    CSV.read(RESIDENTS_CSV_PATH)
  end

  def dropbox
    @dropbox ||= DropboxApi::Client.new(ENV['DROPBOX_APP_KEY'])
  end

  def pdftk
    @pdftk ||= PdfForms.new("/usr/local/bin/pdftk")
  end
end

form = CityHopeHotelForm.new

form.generate_daily_log!
form.generate_weekly_report!