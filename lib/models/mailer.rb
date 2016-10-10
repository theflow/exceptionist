class Mailer
  def self.deliver_new_exceptions(project, day, to_address, body)
    account = Exceptionist.config[:smtp_settings]
    return if account.nil?

    body = <<MESSAGE_END
From: Exceptionist <the@exceptionist.org>
To: Exceptionist <the@exceptionist.org>
MIME-Version: 1.0
Content-type: text/html
Subject: [Exceptionist][#{project.name}] Summary for #{Helper.es_day(day)}

#{body}
MESSAGE_END

    Net::SMTP.start(account[:host], account[:port], 'localhost', account[:user], account[:pass], account[:auth]) do |smtp|
      smtp.send_message(body, 'the@exceptionist.org', to_address)
    end
  end
end
