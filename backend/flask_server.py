import subprocess
import re
from flask import Flask, jsonify, request
import threading
import time
import uuid
import urllib.parse

app = Flask(__name__)

# Dictionary to store the active tunnels for the user by session_id
active_tunnels = {}

# Function to extract the tunnel URL for each request
def extract_tunnel_url(user_id, session_id,url):
    try:
        # Start the process to open the tunnel
        process = subprocess.Popen(
            ["cloudflared", "--url", url],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        # Define the regex pattern for the Cloudflare URL
        url_pattern = re.compile(r"https://[a-zA-Z0-9\-]+\.trycloudflare\.com")

        # Check the output line by line
        while True:
            output = process.stdout.readline()
            if output:
                # Look for the URL in the current output line
                match = url_pattern.search(output)
                if match:
                    # Extract and return the URL
                    tunnel_url = match.group(0)
                    print(f"Tunnel URL for {user_id} (session {session_id}): {tunnel_url}")
                    # Store the process in the active_tunnels dictionary with session_id
                    active_tunnels[user_id][session_id] = process
                    return tunnel_url

            # Exit if the process has finished and no URL was found
            if process.poll() is not None:
                break

        print(f"No URL found in the output for {user_id} (session {session_id}).")
        return None

    except Exception as e:
        print(f"Error creating tunnel for {user_id} (session {session_id}): {e}")
        return None

# Endpoint to create and get the tunnel URL
@app.route('/create_tunnel', methods=['POST'])
def create_tunnel():
    user_id = request.json.get("user_id")  # Get user ID from the request
    if not user_id:
        return jsonify({"error": "Give valid url/userID"}), 400

    # Generate a unique session ID for the new tunnel
    session_id = request.json.get("session_id")

    url = request.json.get("url")

    print(url)
    
    if not(is_valid_url(url)):
        print("Invalid url")
        return jsonify({"error": "Give valid url/userID"}), 400

    # If no tunnels exist for the user, create a new dictionary entry
    if user_id not in active_tunnels:
        active_tunnels[user_id] = {}

    # Extract the tunnel URL
    tunnel_url = extract_tunnel_url(user_id, session_id,url)
    if tunnel_url:
        return jsonify({"session_id": session_id, "tunnel_url": tunnel_url}), 200
    else:
        return jsonify({"error": "Failed to create tunnel URL"}), 500

# Endpoint to destroy a specific tunnel for the user by session ID
@app.route('/destroy_tunnel', methods=['POST'])
def destroy_tunnel():
    user_id = request.json.get("user_id")  # Get user ID from the request
    session_id = request.json.get("session_id")  # Get session ID from the request

    if not user_id or not session_id:
        return jsonify({"error": "user_id and session_id are required"}), 400

    # Check if the user has active tunnels and the session exists
    if user_id in active_tunnels and session_id in active_tunnels[user_id]:
        process = active_tunnels[user_id][session_id]
        try:
            # Terminate the Cloudflare tunnel for this session
            process.terminate()
            process.wait()  # Wait for the process to terminate properly
            del active_tunnels[user_id][session_id]  # Remove the tunnel from the active_tunnels dictionary
            return jsonify({"message": f"Tunnel for {user_id} (session {session_id}) destroyed successfully"}), 200
        except Exception as e:
            return jsonify({"error": f"Error destroying tunnel for {user_id} (session {session_id}): {str(e)}"}), 500
    else:
        return jsonify({"error": f"No active tunnel found for {user_id} (session {session_id})"}), 404


def is_valid_url(url):
    try:
        result = urllib.parse.urlparse(url)
        return all([result.scheme, result.netloc])  # checks if URL has scheme and netloc (like http://example.com)
    except ValueError:
        return False


if __name__ == "__main__":
    app.run(debug=True,host="0.0.0.0",use_reloader=False)  # Set use_reloader=False to avoid running the code twice
