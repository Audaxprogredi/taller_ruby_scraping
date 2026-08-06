
User.find_or_create_by!(email_address: "admin@taller.com") do |user|
  user.password = "admin1234"
  user.password_confirmation = "admin1234"
  user.admin = true
end

puts "Superadmin creado: admin@taller.com / admin1234"