"""
The University of Queensland
Semester 1 2023 COMS3200 Assignment 1 Part C

author: Jamie Katsamatsas 
student id: 46747200

This file contains the implementation of a client in a server client chat 
program for COMS3200.

Usage: python3 chatclient.py port username

TODO remove all instances of todo print statements in all files
"""
import socket
import threading
import sys
import json
import queue
from sender_receiver import SenderReceiver

SERVER_HOST = '127.0.0.1'

class ChatClient:
    """
    Implements a client in a chat application connecting over TCP.
    """
    def __init__(self) -> None:
        # ensure enough cli arguments given
        if len(sys.argv) != 3:
            exit(1)
        
        # exit if arguments are malformed
        try:
            self.server_port: int = int(sys.argv[1])
            self.client_username: str = sys.argv[2]
        except:
            exit(1)

        # client settings sent to server on first connection            
        self.client_settings = {
            "username": self.client_username
        }
        
        # start daemon thread to handle user input
        self.client_command_queue = queue.Queue()
        input_thread = threading.Thread(
            target=self.client_input_thread,
            args=(self.client_command_queue, ),
            daemon=True)
        input_thread.start()
        
         # allows a child thread to signal to parent when the shutdown
        self.shutdown_queue = queue.Queue()
        self.shutdown_client = False # when the client should shutdown

        
    def connect_to_server(self) -> None:
        """
        Connects to the server.
        """
        self.client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            print(f"chatclient connect_to_server port: {self.server_port}")
            self.client_socket.connect((SERVER_HOST, self.server_port))
        except ConnectionRefusedError as e:
            print(f"REMOVE WHEN DONE: server socket connection refused: {e}...", flush=True) # TODO
            exit(1)
        
        
    def start(self):
        """
        Connects to server and starts threads required.
        """
        while self.shutdown_client == False:
            self.connect_to_server()
            
            # send client username on first connection
            self.send_message(self.client_settings)
            # self.client_socket.send(json.dumps(self.client_settings).encode())
            
            # start client command logic that will take messages on the incoming
            # stdin queue and send them to the server connection established 
            # above
            client_command_logic_thread = threading.Thread(
                target=self.client_command_logic_thread,
                args=(self.client_command_queue, ),
                daemon=True)
            client_command_logic_thread.start()

            # start thread to handle incomming messages            
            receiver_thread = threading.Thread(
                target=self.receiver_thread,
                daemon=True)
            receiver_thread.start()
            receiver_thread.join()
            
        # self.shutdown_queue.get(block=True)
        self.shutdown()
        
    
    def close_socket(self) -> None:
        """
        Closes the chat client socket
        """
        # self.client_socket.shutdown(socket.SHUT_RDWR)
        self.client_socket.close()
        
        
    def client_input_thread(self, incoming_commands: queue.Queue):
        """
        Handles processing command line input from the user.
        
        Input provided by the user is send to the server. 
        """
        while True:
            # print("in client input thread")
            # sys.stdin = open("/dev/tty")
            try:
                user_input = input().strip()
                # user_input = sys.stdin.read().strip()
            except EOFError:
                # return
                # print("in kjhfbgdjhfkbg")
                continue
            # print(user_input)
            incoming_commands.put(user_input)
            
            # # if '/send' command used the file needs to be sent in the message
            # first_word = user_input.split(" ")[0]
            # if first_word == "/send":
            #     filename = user_input.split(" ")[2]
                
            #     message = {
            #         "message_type": "basic",
            #         "message": user_input,
            #         "file": self.load_file(filename)
            #     }
                
            #     if self.send_message(message) == False: break
            #     continue
                
            # # message to be send to the server
            # message = {
            #         "message_type": "basic",
            #         "message": user_input
            #     }
            
            # if self.send_message(message) == False: break
        
        # self.shutdown_client = True
        
        
    def client_command_logic_thread(self, incoming_commands: queue.Queue):
        while True:
            # print("in client command thread")
            message = incoming_commands.get(block=True)
            print(message, flush=True)
            
            # if '/send' command used the file needs to be sent in the message
            first_word = message.split(" ")[0]
            if first_word == "/send":
                filename = message.split(" ")[2]
                
                message = {
                    "message_type": "basic",
                    "message": message,
                    "file": self.load_file(filename)
                }
                
                # if send message failed because of broken connection return
                if self.send_message(message) == False: break
                continue
                
            # message to be send to the server
            message = {
                    "message_type": "basic",
                    "message": message
                }
            
            # if send message failed because of broken connection return
            if self.send_message(message) == False: break
            
    
    def load_file(self, filename: str) -> bytes:
        """
        Loads the given file into a bytes string.
        
        Args:
            filename (str): the file to be loaded

        Returns:
            bytes: the bytearray of the file, if file does not exist an empty 
            byte string is returned
            
        Reference:
        [1]    A. Rockikz, "How to Transfer Files in the Network using Sockets 
        in Python." thepythoncode.com. 
        https://www.thepythoncode.com/article/send-receive-files-using-sockets-python 
        (accessed April 5, 2023).
        """
        try:
            with open(filename, "rb") as f:
                file_bytes = f.read()
                return file_bytes
        except FileNotFoundError:
            return b''
        
        
    def save_file(self, filename: str, file_bytes: bytes) -> None:
        """
        Saves a given file on the users system.

        Args:
            filename (str): name of the file to be saved
            file_bytes (bytes): contents of the file to be saved in bytes
        """
        with open(filename, "wb") as f:
            f.write(file_bytes)
        
        
    def send_message(self, message: dict) -> None:
        """
        Sends the given message to the connected server.
        
        Args:
            message (dict): dictionary containing the message information and 
            metadata to be sent
        """
        # if SenderReceiver.send_message(message, self.client_socket) == True:
        #     return
        
        # # if send_message returned false the server must be closed, so shutdown 
        # # client
        # self.shutdown()
        # print(message, flush=True)
        # print(message["message"], flush=True)
        return SenderReceiver.send_message(message, self.client_socket)
        
        
    def receiver_thread(self) -> None:
        """
        Listens for incoming messages from the server and processes them.
        
        Messages marked as 'basic' are to be printed out to the clients stdout.
        If the message contains a file or a command this will require further 
        processing.
        
        References:
        [2]     G. McMillan, "Socket Programming HOWTO" python.org. 
        https://docs.python.org/3/howto/sockets.html (accessed April 5, 2023)
        """
        while True:
            message = SenderReceiver.receive_message(self.client_socket)
            
            # message = None indicated the thread should be closed            
            if message is None: return
                
            # save the file if one in message
            if message["file_exists"] == True:
                filename = message["args"][1]
                file_bytes = message["file"]
                self.save_file(filename, file_bytes)
            
            elif message["message_type"] == "command":
                self.handle_server_command(message)
                
            elif message["message_type"] == "basic":
                print(message["message"], flush=True)
            
            
    def handle_server_command(self, message: dict) -> None:
        """
        Handles incoming server commands.
        
        Commands:
            '/shutdown' - the client will shutdown gracefully closing all 
            sockets and threads.
            '/switch' - the current connection to the server will close and a 
            new connection to the given server will start

        Args:
            message (dict): the message containing the command and any other 
            data
        """
        command = message["command"]
        if command == "/shutdown":
            self.shutdown()
            return
        elif command == "/switch":
            args = message["args"]
            self.switch(args)
            return


    def shutdown(self) -> None:
        """
        Shutsdown the client.
        
        Socket connections are closed and the main thread exists. All threads 
        marked as daemon will shutdown automatically.
        """
        self.close_socket()
        self.shutdown_queue.put(1)
        self.shutdown_client = True


    def switch(self, args: list) -> None:
        """
        Connects the client to a new channel.
        
        The client is manually disconnected from the current channel and the 
        client will auto reconnect to a new channel provided by 'args'.

        Args:
            args (list): switch command arguments provided by the server, 
            contains the new server port.
        """
        new_channel_port = int(args[0])
        self.server_port = new_channel_port
        self.close_socket()


def main():
    client = ChatClient()
    client.start()


if __name__ == "__main__":
    main()