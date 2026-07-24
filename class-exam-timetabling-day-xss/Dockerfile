# Vulnerable lab: SourceCodester Class and Exam Timetabling System V1.0
# Reflected XSS in admin/class.php via the `day` parameter.
# Ref: https://github.com/ashfaqsharif47-arch/Web-RCE/issues/1
#
# This is a minimal, self-contained reproduction of the reported sink so the
# vulnerability can be exercised without the gated SourceCodester download or a
# full XAMPP + MySQL stack (the XSS reflection needs no database).
FROM php:8.2-apache

# Copy the vulnerable application into the Apache document root.
COPY www/ /var/www/html/

EXPOSE 80
