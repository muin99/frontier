"""Publish the user's requested game assets using their existing Git credential.

Credentials stay in memory and are never written to logs or files.
"""
import argparse
import json
from pathlib import Path
import subprocess
import urllib.error
import urllib.parse
import urllib.request

REPO = 'muin99/frontier'
TAG = 'v0.13.0'

def credential():
    result = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\nusername=muin99\n\n', text=True, capture_output=True, timeout=45)
    if result.returncode:
        raise RuntimeError('GitHub sign-in is required for muin99.')
    values = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
    if not values.get('password'):
        raise RuntimeError('No GitHub credential returned.')
    return values['password']

TOKEN = None

def request(path, method='GET', body=None, content_type='application/json'):
    url = path if path.startswith('https://') else 'https://api.github.com' + path
    if urllib.parse.urlparse(url).hostname not in ('api.github.com', 'uploads.github.com'):
        raise RuntimeError('Unexpected GitHub API host.')
    headers = {'Authorization': 'Bearer ' + TOKEN, 'User-Agent': 'Mohashunnyo-release', 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'}
    if isinstance(body, dict):
        body = json.dumps(body).encode()
    if body is not None:
        headers['Content-Type'] = content_type
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=300) as response:
            data = response.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        if error.code == 404 and method == 'GET':
            return None
        raise RuntimeError(f'GitHub API returned HTTP {error.code} for {urllib.parse.urlparse(url).path}') from None

def main():
    global TOKEN
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['inspect', 'draft', 'upload', 'publish'])
    parser.add_argument('files', nargs='*')
    args = parser.parse_args()
    TOKEN = credential()
    user = request('/user')
    if user['login'].lower() != 'muin99':
        raise RuntimeError('The authenticated GitHub account is not muin99.')
    print('Authenticated account:', user['login'], flush=True)
    base = '/repos/' + REPO
    release = request(base + '/releases/tags/' + TAG)
    if not release:
        release = next((r for r in request(base + '/releases') if r['tag_name'] == TAG), None)
    if args.action == 'inspect':
        print(json.dumps({'release_exists': bool(release), 'tag': TAG, 'draft': release.get('draft') if release else None}))
        return
    if not release:
        if args.action != 'draft':
            raise RuntimeError('Create the draft release first.')
        release = request(base + '/releases', 'POST', {'tag_name': TAG, 'target_commitish': 'main', 'name': 'Mohashunnyo — Judge Edition / Frontier 13', 'draft': True, 'body': 'Release assets are being verified.'})
    if args.action == 'upload':
        for filename in args.files:
            path = Path(filename)
            current = request(base + '/releases/' + str(release['id']) + '/assets')
            if any(a['name'] == path.name for a in current):
                raise RuntimeError('Release asset already exists: ' + path.name)
            url = release['upload_url'].split('{')[0] + '?name=' + urllib.parse.quote(path.name)
            mime = 'video/mp4' if path.suffix == '.mp4' else ('application/zip' if path.suffix == '.zip' else 'text/plain')
            asset = request(url, 'POST', path.read_bytes(), mime)
            print('Uploaded:', asset['name'], asset['size'], flush=True)
    if args.action == 'publish':
        body = Path(args.files[0]).read_text(encoding='utf-8')
        release = request(base + '/releases/' + str(release['id']), 'PATCH', {'draft': False, 'body': body, 'make_latest': 'true'})
        print('Published:', release['html_url'])
    else:
        print('Release:', release['html_url'], 'draft=', release['draft'])

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit(str(error))
