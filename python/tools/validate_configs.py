# Configuration Validator Script

import json
import os


def validate_json(file_path):
    """ Validate a JSON configuration file. """
    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"{file_path} does not exist.")

    try:
        with open(file_path, 'r') as f:
            json.load(f)
        print(f"{file_path} is valid JSON.")
    except json.JSONDecodeError as e:
        print(f"Error in {file_path}: {e}")


if __name__ == '__main__':
    # Example usage: validate_json('config.json')
    config_path = 'path/to/your/config.json'  # Change this to your config file path
    validate_json(config_path)