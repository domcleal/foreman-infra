#!/usr/bin/env python
#
# This script uses the Duffy node management api to get fresh machines to run
# CI tests on.
#
# Adapted from https://github.com/kbsingh/centos-ci-scripts

import json, urllib, subprocess, sys, os.path

with open(os.path.expanduser('~/duffy.key'), 'r') as f:
  api = f.readline().rstrip()

url_base="http://admin.ci.centos.org:8080"
ver="7"
arch="x86_64"
count=1

print "Requesting %s hosts running CentOS %s" % (count, ver)
get_nodes_url="%s/Node/get?key=%s&ver=%s&arch=%s&i_count=%s" % (url_base,api,ver,arch,count)

dat=urllib.urlopen(get_nodes_url).read()
print dat
b=json.loads(dat)

with open('hosts', 'w') as f:
  f.write("\n".join(b['hosts']))

with open('ssid', 'w') as f:
  f.write(b['ssid'])
