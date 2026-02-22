import requests
import csv
import click

@click.command()
@click.argument('csv_file_path', type=click.Path(exists=True))
@click.option('--session', required=True, help='Session cookie for authentication')
@click.option('--title', default='Default Title', help='Title for the benchmark')
@click.option('--description', default='Default Description', help='Description for the benchmark')
def upload(csv_file_path, session, title, description):
    """
    Upload CSV data to the FlightlessSomething API.
    """
    url = "https://api.flightlesssomething.com/benchmark"
    
    # Prepare files for multipart upload
    files = {'file': open(csv_file_path, 'rb')}
    
    headers = {
        'Cookie': session,
        'Title': title,
        'Description': description
    }
    
    try:
        response = requests.post(url, files=files, headers=headers)
        response.raise_for_status()  # Raise an error for bad responses

        # Assuming the API returns a JSON response with the benchmark URL
        data = response.json()
        benchmark_url = data.get('benchmark_url')
        
        if benchmark_url:
            print(f"Upload successful! Benchmark URL: {benchmark_url}")
        else:
            print("Upload successful, but no URL returned.")
    
    except requests.exceptions.HTTPError as err:
        print(f"HTTP error occurred: {err}")
    except Exception as err:
        print(f"An error occurred: {err}")
    finally:
        files['file'].close()

if __name__ == "__main__":
    upload()