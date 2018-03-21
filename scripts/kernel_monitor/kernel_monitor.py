#!/usr/bin/env python3
#
# Copyright (c) 2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Linux Kernel LTS monitor script.

Usage: kernel_monitor.py [--server=HOSTNAME] [--log-file=PATH]
                         [--sender=ADDRESS] [--recipient=ADDRESS]
                         [--recipient=ADDRESS] [--recipient=ADDRESS]
                         [--recipient=ADDRESS] [--recipient=ADDRESS]
       kernel_monitor.py (-h | --help)



Options:
  -h --help              Show this screen.
  --log-file=PATH        Path of a file to dump logs [default: ./kernel_monitor.log]
  --server=HOSTNAME      SMTP server ip or hostname [default: 127.0.0.1]
  --sender=ADDRESS       e-mail sender [default: no-reply@linuxlts.mon]
  --recipient=ADDRESS    e-mail recipients [default: root@localhost]

"""

import os
import sys
import logging
import re
import fileinput
import feedparser
import smtplib
import semver
import json
import urllib3

from docopt import docopt
from email.mime.text import MIMEText
from tempfile import mkstemp
from shutil import move
from os import fdopen, remove
from pathlib import Path

# Parent directory of this script
script_path = os.path.dirname(os.path.realpath(__file__))
versions_file=script_path + "/../../versions.txt"

# The folowing xml file is used to fetch the latest Linux kernel info
kernel_xml_url = "https://www.kernel.org/feeds/kdist.xml"

def get_current_lts():
    lts_string=''
    f = open(versions_file, 'r')
    for line in f:
        if re.match('current_lts_linux', line):
            lts_string=line.split("=")[1]
    f.close()
    return lts_string

def update_versions_file(new_lts, current_lts):
    temp_file, abs_path = mkstemp()
    with fdopen(temp_file,'w') as new_file:
        with open(versions_file) as old_file:
            for line in old_file:
                new_file.write(line.replace("current_lts_linux=" + current_lts, "current_lts_linux=" + new_lts + '\n'))
    remove(versions_file)
    move(abs_path, versions_file)
    logging.info("Updated versions.txt file")

def discover_certs():
    cert_files = [
	"/etc/ssl/certs/ca-certificates.crt",                # Debian/Ubuntu/Gentoo etc.
	"/etc/pki/tls/certs/ca-bundle.crt",                  # Fedora/RHEL 6
	"/etc/ssl/ca-bundle.pem",                            # OpenSUSE
	"/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", # CentOS/RHEL 7
        "/var/cache/ca-certs/anchors",                       # Kata Linux certs directory
        "/etc/pki/tls/cacert.pem",                           # Others
    ]
    cert_bundle=''
    for file in cert_files:
        abs_path=Path(file).resolve()
        if abs_path.exists():
            logging.info("Certificates bundle: " + file)
            cert_bundle = abs_path
            break

    if cert_bundle == '':
        logging.error("No certificates found.")
        sys.exit(1)

    return cert_bundle

class email(object):
    def __init__(self, sender, recipients, smtp_server):
        self.sender = sender
        self.recipients = recipients
        self.smtp_server = smtp_server

    def send(self, new_lts, current_lts):
        email_body="A new LTS version of the Linux kernel is out: " + new_lts + "\n" \
                   "Current version: " + current_lts
        msg = MIMEText(email_body)

        try:
            s = smtplib.SMTP(self.smtp_server)
            logging.info("SMTP server: " + self.smtp_server)
            logging.info("Sender: " + self.sender)
            logging.info("Recipients: " + ','.join(self.recipients))

            msg['Subject'] = 'New LTS Kernel available'
            msg['From'] = self.sender
            msg['To'] = ', '.join(self.recipients)
            s.sendmail(self.sender, self.recipients, msg.as_string())
            logging.info("Email sent!")
            s.quit()
        except smtplib.SMTPException:
            logging.error("Error: unable to send email")

if __name__ == '__main__':
    arguments = docopt(__doc__)
    logging.basicConfig(filename=arguments['--log-file'],
                        level=logging.DEBUG,
                        format='%(asctime)s %(message)s',
                        datefmt='%m/%d/%Y %I:%M:%S %p')

    logging.info("*** Linux LTS Monitor Tool ***")
    distro_certs = discover_certs()
    if Path(distro_certs).is_file():
        http = urllib3.proxy_from_url(os.environ['https_proxy'],
                                      cert_reqs='REQUIRED',
                                      ca_certs=distro_certs)
    elif Path(distro_certs).is_dir():
        http = urllib3.proxy_from_url(os.environ['https_proxy'],
                                      cert_reqs='REQUIRED',
                                      ca_cert_dir=distro_certs)
    
    request = http.request('GET', kernel_xml_url)
    feed_data = feedparser.parse(request.data)

    current_lts_kernel = get_current_lts()
    for entry in feed_data['entries']:
        version = entry['title'].split(':')[0]
        build_type = entry['title'].split(' ')[1]
        if build_type == "longterm" and semver.match(version, '>' + current_lts_kernel):
            logging.info("New LTS Kernel available: " + version)
            # email setup
            new_email = email(arguments['--sender'],
                              arguments['--recipient'],
                              arguments['--server'])
            new_email.send(version, current_lts_kernel)
            update_versions_file(version, current_lts_kernel)
            break
        elif build_type == "longterm" and semver.match(version, '==' + current_lts_kernel):
            logging.info("Linux LTS  Kernel is up to date: " + current_lts_kernel)
