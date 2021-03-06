#!/usr/bin/python

"""
A simple example script to automatically submit a job to the ModLoop server
then wait for the results. It uses the REST interface automatically set up
by the web server framework.
"""

from __future__ import print_function

rest_url = 'http://salilab.org/modloop/job'

import urllib2
import sys
from xml.dom.minidom import parseString
import xml.parsers.expat
import time
import subprocess

def submit_job(pdb, modkey, loops):
    # Sadly Python currently has no method to POST multipart forms, so we
    # use curl instead
    p = subprocess.Popen(['/usr/bin/curl', '-s', '-L', '-F', 'pdb=@' + pdb,
                          '-F', 'modkey=' + modkey, '-F', 'loops=' + loops,
                          rest_url], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)
    (out, err) = p.communicate()
    exitval = p.wait()
    if exitval != 0:
        raise OSError("curl failed with exit %d; stderr:\n%s" % (exitval, err))
    try:
        dom = parseString(out)
    except xml.parsers.expat.ExpatError:
        print("Web service did not return valid XML:\n" + out, file=sys.stderr)
        raise

    top = dom.getElementsByTagName('saliweb')[0]
    for results in top.getElementsByTagName('job'):
        url = results.getAttribute('xlink:href')
        dom.unlink()
        return url
    dom.unlink()
    raise IOError("Cannot submit job: " + out + err)

def get_results(url):
    while True:
        try:
            u = urllib2.urlopen(url)
            return u
        except urllib2.HTTPError as detail:
            if detail.code == 503:
                print("Not done yet: waiting and retrying")
            else:
                raise
        time.sleep(30)

def main():
    pdb = 'modeller/examples/atom_files/1fdx.B99990001.pdb'
    modkey = 'MY_MODELLER_KEY'
    loops = '1::5::'
    url = submit_job(pdb, modkey, loops)
    print("Results will be found at " + url)

    u = get_results(url)
    dom = parseString(u.read())

    print("Got results:")
    top = dom.getElementsByTagName('saliweb')[0]
    for results in top.getElementsByTagName('results_file'):
        url = results.getAttribute('xlink:href')
        print("   " + url)
        u = urllib2.urlopen(url)
        print(u.read())
    dom.unlink()

if __name__ == '__main__':
    main()
