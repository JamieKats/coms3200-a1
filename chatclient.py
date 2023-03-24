from socket import *
import sys
import json

SERVER_NAME = '127.0.0.1'
SERVER_PORT = 12000

class Client:
    def __init__(self) -> None:
        # load channel info
        self.server_port = int(sys.argv[1])
        self.client_username = sys.argv[2]
        client_settings = {
            "port": self.server_port,
            "username": self.client_username
        }
        
        self.connect_to_server(client_settings)
        
        
    def connect_to_server(self, client_settings: dict):
        self.client_socket = socket(AF_INET, SOCK_STREAM)
        self.client_socket.connect((SERVER_NAME, SERVER_PORT))
        
        # send client username
        self.client_socket.send(json.dumps(client_settings).encode())
        
        
def main():
    client = Client()

    
        
if __name__ == "__main__":
    main()