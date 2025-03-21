import os
import time
import requests
import hashlib
from github import Github


def get_github_latest_release():
    g = Github()
    repo = g.get_repo("xOS/Snell")
    release = repo.get_latest_release()
    if release:
        print(f"Latest release tag is: {release.tag_name}")
        print(f"Latest release info is: {release.body}")
        files = []
        for asset in release.get_assets():
            url = asset.browser_download_url
            name = asset.name

            response = requests.get(url)
            if response.status_code == 200:
                with open(name, 'wb') as f:
                    f.write(response.content)
                print(f"Downloaded {name}")
            else:
                print(f"Failed to download {name}")
            file_abs_path = get_abs_path(asset.name)
            files.append(file_abs_path)
        print('Checking file integrities')
        verify_checksum(get_abs_path("checksums.txt"))
        sync_to_gitee(release.tag_name, release.body, files)
    else:
        print("No releases found.")


def delete_gitee_releases(latest_id, client, uri, token):
    get_data = {
        'access_token': token
    }

    release_info = []
    release_response = client.get(uri, json=get_data)
    if release_response.status_code == 200:
        release_info = release_response.json()
    else:
        print(
            f"Request failed with status code {release_response.status_code}")

    release_ids = []
    for block in release_info:
        if 'id' in block:
            release_ids.append(block['id'])

    print(f'Current release ids: {release_ids}')
    release_ids.remove(latest_id)

    for id in release_ids:
        release_uri = f"{uri}/{id}"
        delete_data = {
            'access_token': token
        }
        delete_response = client.delete(release_uri, json=delete_data)
        if delete_response.status_code == 204:
            print(f'Successfully deleted release #{id}.')
        else:
            raise ValueError(
                f"Request failed with status code {delete_response.status_code}")


def sync_to_gitee(tag: str, body: str, files: slice):
    release_id = ""
    owner = "Ten"
    repo = "ServerAgent"
    release_api_uri = f"https://gitee.com/api/v5/repos/{owner}/{repo}/releases"
    api_client = requests.Session()
    api_client.headers.update({
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    })

    access_token = os.environ['GITEE_TOKEN']
    release_data = {
        'access_token': access_token,
        'tag_name': tag,
        'name': tag,
        'body': body,
        'prerelease': False,
        'target_commitish': 'master'
    }
    while True:
        try:
            release_api_response = api_client.post(
                release_api_uri, json=release_data, timeout=30)
            release_api_response.raise_for_status()
            break
        except requests.exceptions.Timeout as errt:
            print(f"Request timed out: {errt} Retrying in 60 seconds...")
            time.sleep(60)
        except requests.exceptions.RequestException as err:
            print(f"Request failed: {err}")
            break
    if release_api_response.status_code == 201:
        release_info = release_api_response.json()
        release_id = release_info.get('id')
    else:
        print(
            f"Request failed with status code {release_api_response.status_code}")

    print(f"Gitee release id: {release_id}")
    asset_api_uri = f"{release_api_uri}/{release_id}/attach_files"

    for file_path in files:
        success = False

        while not success:
            files = {
                'file': open(file_path, 'rb')
            }

            asset_api_response = requests.post(
                asset_api_uri, params={'access_token': access_token}, files=files)

            if asset_api_response.status_code == 201:
                asset_info = asset_api_response.json()
                asset_name = asset_info.get('name')
                print(f"Successfully uploaded {asset_name}!")
                success = True
            else:
                print(
                    f"Request failed with status code {asset_api_response.status_code}")

    # 仅保留最新 Release 以防超出 Gitee 仓库配额
    try:
        delete_gitee_releases(release_id, api_client,
                              release_api_uri, access_token)
    except ValueError as e:
        print(e)

    api_client.close()
    print("Sync is completed!")


def get_abs_path(path: str):
    wd = os.getcwd()
    return os.path.join(wd, path)


def compute_sha256(file: str):
    sha256_hash = hashlib.sha256()
    buf_size = 65536
    with open(file, 'rb') as f:
        while True:
            data = f.read(buf_size)
            if not data:
                break
            sha256_hash.update(data)
    return sha256_hash.hexdigest()


def verify_checksum(checksum_file: str):
    with open(checksum_file, 'r') as f:
        lines = f.readlines()

    for line in lines:
        checksum, file = line.strip().split()
        abs_path = get_abs_path(file)
        computed_hash = compute_sha256(abs_path)

        if checksum == computed_hash:
            print(f"{file}: OK")
        else:
            print(f"{file}: FAIL (expected {checksum}, got {computed_hash})")
            print("Will run the download process again")
            get_github_latest_release()
            break


get_github_latest_release()