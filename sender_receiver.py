"""
The University of Queensland
Semester 1 2023 COMS3200 Assignment 1 Part C

author: Jamie Katsamatsas 
student id: 46747200

This file implements send and receive messages for TCP. This file is used by 
both the server and client to send a receive messages.

TODO remove all instances of todo print statements in all files
"""
import json
import socket

TCP_MSG_LENGTH_DIGITS = 9

MAX_BUFFER_SIZE = 4096


class SenderReceiver:
    
    @staticmethod
    def send_message(message: dict, conn_socket: socket) -> bool:
        """
        Sends the given message to the given TCP socket.
        
        The length of the message is sent first, then the encoded mesage is 
        sent after.

        Args:
            message (dict): message to be sent
            conn_socket (socket): TCP socket the message is sent over

        Returns:
            bool: True if the message was sent successfully, False otherwise.
            Typically False indicates an issue with the socket e.g. a 
            closed socket.
        """
        # if the message contains a file update values in the message metadata
        message["file_exists"] = False
        if "file" in message.keys():
            file_bytes = message["file"]
            del message["file"]
            message["file_exists"] = True
        
        # calculate the length of the message to send in a 9 digit string
        encoded_message = json.dumps(message).encode()
        encoded_message_len = len(encoded_message)
        encoded_message_len = f"{encoded_message_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()

        # send the message length and the message
        try:
            conn_socket.sendall(encoded_message_len)
            conn_socket.sendall(encoded_message)
        except BrokenPipeError or ConnectionResetError:
            return False
        
        # if there is a file in the message then the file length and file 
        # bytes is sent seperately 
        if message["file_exists"]:
            file_len = len(file_bytes)
            file_len = f"{file_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()
            
            try:        
                conn_socket.sendall(file_len)
                conn_socket.sendall(file_bytes)
            except BrokenPipeError:
                return False
            
        return True
        
        
    @staticmethod
    def receive_message(conn_socket: socket) -> dict:
        """
        Receive message over TCP.
        
        The length of the message is first received then the message is received.
        
        Args:
            conn_socket (socket): TCP socket to read the message off

        Returns:
            dict: the message read from the TCP socket
            
        [4]     J. Xu, "Handling Message Boundary in Socket Programming" 
        enzircle.com. 
        https://enzircle.com/handling-message-boundaries-in-socket-programming 
        (accessed April 10)
        """
        # receive the message length
        try:
            msg_length = conn_socket.recv(TCP_MSG_LENGTH_DIGITS).decode()
        except OSError:
            return None

        # convert it to an integer        
        try:
            msg_length = int(msg_length)
        except ValueError:
            return None
        
        # read in the number of bytes received
        bytes_read = 0
        message = ''
        while bytes_read < msg_length:
            buffer_size = min(MAX_BUFFER_SIZE, msg_length - bytes_read)
            encoded_message = conn_socket.recv(buffer_size)
            message += encoded_message.decode()
            bytes_read += buffer_size
            
        message = json.loads(message)
        
        # check if file expected
        if message["file_exists"] == False: return message
        
        # if the file is expected receive the length of the file
        try:
            msg_length = conn_socket.recv(TCP_MSG_LENGTH_DIGITS).decode()
        except OSError:
            return None
        
        try:
            msg_length = int(msg_length)
        except ValueError:
            return None
        
        # read the file from the TCP socket
        bytes_read = 0
        chunks = []
        while bytes_read < msg_length:
            buffer_size = min(MAX_BUFFER_SIZE, msg_length - bytes_read)
            chunk = conn_socket.recv(buffer_size)
            chunks.append(chunk)
            bytes_read += len(chunk)

        message["file"] = b''.join(chunks)
        return message
                
            