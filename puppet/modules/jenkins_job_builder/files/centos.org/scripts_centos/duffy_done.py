#!/usr/bin/env python
#
# This script uses the Duffy node management api to mark machines as done
#
# Adapted from https://github.com/kbsingh/centos-ci-scripts

import json, urllib, subprocess, sys, os.path

with open(os.path.expanduser('~/duffy.key'), 'r') as f:
  api = f.readline().rstrip()

url_base="http://admin.ci.centos.org:8080"

with open('ssid', 'r') as f:
  ssid = f.readline().rstrip()

print "Marking hosts under SSID %s as done" % (ssid)
done_nodes_url="%s/Node/done?key=%s&ssid=%s" % (url_base, api, ssid)
