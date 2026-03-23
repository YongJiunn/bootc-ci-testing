#!/bin/bash
set -xeuo pipefail

# Install OpenSCAP scanner and security content to the image
dnf install -y openscap-utils scap-security-guide && dnf clean all

# Run scan and hardening including the tailoring file
# https://www.mankier.com/8/oscap-im

# replace tailoring-file accordingly to the generated tailoring file 
oscap-im --tailoring-file /usr/share/ssg-cs9-ds-tailoring.xml --profile xccdf_org.ssgproject.content_profile_cis_customized /usr/share/xml/scap/ssg/content/ssg-cs9-ds.xml

# non-automatic remediation

# cis 5.1.7
# WARNING: Automated remediation is not available for this configuration check because each system has unique user names and group names.
# can because only got 2 users at one time - starforge, postgres_user that can ssh
{
    echo "AllowUsers starforge postgres_user"
    echo "DenyUsers nobody"
} >> "/etc/ssh/sshd_config.d/99-ssh-access.conf"