class Contacts
  CONTACTS = YAML.load(IO.read("config/contacts.yml"))

  def self.all
    CONTACTS
  end
end
