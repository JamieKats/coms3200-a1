import json
import socket

TCP_MSG_LENGTH_DIGITS = 9

MAX_BUFFER_SIZE = 4096


class SenderReceiver:
    
    @staticmethod
    def send_message(message: dict, conn_socket: socket) -> bool:
        """
        Send encoded message length then send the message after

        Args:
            message (dict): _description_
        """
        message["file_exists"] = False
        if "file" in message.keys():
            file_bytes = message["file"]
            del message["file"]
            message["file_exists"] = True
        
        encoded_message = json.dumps(message).encode()
        encoded_message_len = len(encoded_message)
        encoded_message_len = f"{encoded_message_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()

        try:
            # print(f"\nsend in sender_recevver: msg len: {encoded_message_len}\nmsg: {encoded_message}\n")
            conn_socket.sendall(encoded_message_len)
            conn_socket.sendall(encoded_message)
        except BrokenPipeError or ConnectionResetError:
            # print("\nBROKEN PIPE IN send_message sender_recevier\n")
            return False
        
        if message["file_exists"]:
            file_len = len(file_bytes)
            file_len = f"{file_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()
            
            try:        
                conn_socket.sendall(file_len)
                conn_socket.sendall(file_bytes)
            except BrokenPipeError:
                return False
            
        # print("in send msg")
        return True
        
        
    @staticmethod
    def receive_message(conn_socket: socket) -> dict:
        """
        Reference for fix to get send of large files working well using chunks
        https://enzircle.com/handling-message-boundaries-in-socket-programming
        
        Returns None if an error occured at some point, close connection if so.

        Args:
            conn_socket (socket): _description_

        Returns:
            dict: _description_
        """
        try:
            msg_length = conn_socket.recv(TCP_MSG_LENGTH_DIGITS).decode()
        except OSError:
            return None
        # print(f"msg len receved in sender recevier\n{msg_length}")
        
        try:
            msg_length = int(msg_length)
        except ValueError:
            return None
        
        bytes_read = 0
        message = ''
        while bytes_read < msg_length:
            buffer_size = min(MAX_BUFFER_SIZE, msg_length - bytes_read)
            encoded_message = conn_socket.recv(buffer_size)
            message += encoded_message.decode()
            bytes_read += buffer_size
            
        # print(f"msg receved in sender recevier\n{message}")
        message = json.loads(message)
        
        # check if file expected
        if message["file_exists"] == False: return message
        
        try:
            msg_length = conn_socket.recv(TCP_MSG_LENGTH_DIGITS).decode()
        except OSError:
            return None
        
        try:
            msg_length = int(msg_length)
        except ValueError:
            return None
        
        bytes_read = 0
        chunks = []
        while bytes_read < msg_length:
            buffer_size = min(MAX_BUFFER_SIZE, msg_length - bytes_read)
            chunk = conn_socket.recv(buffer_size)
            chunks.append(chunk)
            bytes_read += len(chunk)

        message["file"] = b''.join(chunks)
        return message
                
            