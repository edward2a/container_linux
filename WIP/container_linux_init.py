#!/usr/bin/env python3
"""Container Linux Init Script."""

import argparse
import re
import os
from urllib.request import urlopen


user_data_url = 'http://169.254.169.254/latest/user-data'
user_data_filter = r'^[^\=\n\s-]*\={1}[^\n\s][\"\']?.*[\"\']?$'
var_stripper  = '\'\"'


def check_user():
    if not os.getuid() == 0:
        print('User must be root!')
        exit(1)


def load_args():
    """Empty argument parser for future use."""
    p = argparse.ArgumentParser()

    return p.parse_args()


def load_user_data_vars(strip_quoting=False, data_filter=user_data_filter, url=user_data_url):
    """Parse user-data and return dict with the filtered shell vars."""
    default_var_separator = ';'
    pattern = re.compile(data_filter)

    with urlopen(url) as remote:
        user_data = remote.read().decode().split('\n')

    user_data_vars = {}
    for var in user_data:
        if re.match(pattern, var):
            k, v = var.split('=', 1)
            user_data_vars[k] = v.strip(var_stripper)

    # Add a default var separator for future use if one not present
    if not user_data_vars.get('containerVarSeparator'):
        user_data_vars['containerVarSeparator'] = default_var_separator

    return user_data_vars


def process_user_data_vars(data):
    """Post processing of user-data variables.

    Converts CSV style strings to list/dict.
    """

    data['containerPorts'] = data['containerPorts'].split(',')
    data['containerVars'] = dict([item.split('=', 1) for item in
        data['containerVars'].split(data['containerVarSeparator'])])
    for k, v in data['containerVars'].items():
        data['containerVars'][k] = v.strip(var_stripper)

    data['logOptions'] = dict([item.split('=', 1) for item in
        data['logOptions']])


def pull_container(client, image, tag):
    """Pull docker container image."""
    r = client.pull(image, tag=tag)


def check_old_container(client, name):
    """Check if a previous container exists and remove it."""
    try:
        c = client.containers.get(name)
        c.remove(v=True, force=True)

    except docker.errors.NotFound:
        return False


def start_container(client, data, name):
    log_config = {
        'type': data['loggingDriver'],
        'config': {
            'mode': 'non-blocking',
            'max-buffer-size': '32m'
        }
    }
    #log_config['config'].update(dict([]))
    dkr.create_container(image, tag=tag, detach=True, ports=ports, name=name, )

def main():
    container_name = '{}_{}'.format(
        re.sub(r'^.*/', '', user_data['imageName']),
        user_data['imageTag'])

    check_user()
    user_data = load_user_data_vars()
    process_user_data_vars(user_data)
    dkr = docker.from_env()
    pull_container(dkr, image=user_data['imageName'], tag=user_data['imageTag'])
    check_old_container(dkr, name=container_name)

if __name__ == __main__:
    main()
