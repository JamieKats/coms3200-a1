from socket import *
import sys
import json

SERVER_NAME = '127.0.0.1'
SERVER_PORT = 14000

MSG_BUFFER_SIZE = 4096

class Client:
    def __init__(self) -> None:
        # load channel info
        self.server_port = int(sys.argv[1])
        self.client_username = sys.argv[2]
        self.client_settings = {
            "port": self.server_port,
            "username": self.client_username
        }

        
    def connect_to_server(self):
        self.client_socket = socket(AF_INET, SOCK_STREAM)
        try:
            self.client_socket.connect((SERVER_NAME, SERVER_PORT))
        except ConnectionRefusedError as e:
            print(f"REMOVE WHEN DONE: server socket connection refused: {e}...")
            exit(1)
        
        
    def start(self):
        """
        main thread does nothing (waits for children to finish)
        child_1
            - handles user input and passes to outgoing queue
        child_2
            - checks outgoing queue and sends outgoing messages
            - processes incoming messages:
                - print to screen
                - shut down client (/kick, /empty)
                - switch mute flag (/mute))
        """
        self.connect_to_server()
        
        # send client username
        self.client_socket.send(json.dumps(self.client_settings).encode())
        
        # receive welcome message
        welcome_msg = self.client_socket.recv(MSG_BUFFER_SIZE)
        welcome_msg = json.loads(welcome_msg.decode())
        print(welcome_msg["msg"])
        
        # spin up thread to handle incoming/outgoing message queues
        
        # listen for server message
        while True:
            self.client_socket.recv(MSG_BUFFER_SIZE)
            
            print()
        
        
        
        
def main():
    client = Client()
    client.start()
    
        
if __name__ == "__main__":
    main()