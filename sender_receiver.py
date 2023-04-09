import json
import socket

TCP_MSG_LENGTH_DIGITS = 9

MAX_BUFFER_SIZE = 4096


class SenderReceiver:
    
    @staticmethod
    def send_message(message: dict, conn_socket: socket) -> None:
        """
        Send encoded message length then send the message after

        Args:
            message (dict): _description_
        """
        # encode metadata and message and calculate length of both
        # message = message_data["message"]
        # del message_data["message"]
        
        # encoded_metadata = json.dumps(message).encode()
        # encoded_message = message.encode()
        
        # encoded_metadata_len = len(encoded_metadata)
        # encoded_message_len = len(encoded_message)
        # encoded_metadata_len = f"{encoded_metadata_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()
        # encoded_message_len = f"{encoded_message_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()

        # # conn_socket.send(encoded_message_len)
        # # conn_socket.send(encoded_message)
        # conn_socket.sendall(encoded_metadata_len)
        # conn_socket.sendall(encoded_metadata)
        # conn_socket.sendall(encoded_message_len)
        # conn_socket.sendall(encoded_message)
        message["file_exists"] = False
        if "file" in message.keys():
            file_bytes = message["file"]
            del message["file"]
            message["file_exists"] = True
        # print(message)
        
        encoded_message = json.dumps(message).encode()
        encoded_message_len = len(encoded_message)
        encoded_message_len = f"{encoded_message_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()

        conn_socket.sendall(encoded_message_len)
        conn_socket.sendall(encoded_message)
        
        if message["file_exists"]:
            file_len = len(file_bytes)
            file_len = f"{file_len:0{TCP_MSG_LENGTH_DIGITS}d}".encode()
            
            conn_socket.sendall(file_len)
            conn_socket.sendall(file_bytes)
        
    @staticmethod
    def receive_message(conn_socket: socket) -> dict:
        """
        Reference for fix to get send of large files working well using chunks
        https://enzircle.com/handling-message-boundaries-in-socket-programming

        Args:
            conn_socket (socket): _description_

        Returns:
            dict: _description_
        """
        try:
            msg_length = conn_socket.recv(TCP_MSG_LENGTH_DIGITS).decode()
        except OSError:
            return None
        
        try:
            msg_length = int(msg_length)
        except ValueError:
            return None
        
        bytes_read = 0
        message = ''
        
        while bytes_read < msg_length:
            # print("received a msg chunk")
            buffer_size = min(MAX_BUFFER_SIZE, msg_length - bytes_read)
            encoded_message = conn_socket.recv(buffer_size)
            message += encoded_message.decode()
            bytes_read += buffer_size
            
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
        # file_bytes = b''
        while bytes_read < msg_length:
            # print("HELLO WORLD")
            buffer_size = min(MAX_BUFFER_SIZE, msg_length - bytes_read)
            chunk = conn_socket.recv(buffer_size)
            # file_bytes += encoded_message
            chunks.append(chunk)
            bytes_read += len(chunk)
            # bytes_read += buffer_size
            # print(f"in receive: bytes_read: {bytes_read}    msg len: {msg_length}")
            
        # message["file"] = file_bytes
        message["file"] = b''.join(chunks)
        # print(message)
        # print(f"in receive: bytes_read: {bytes_read}    len file_bytes: {len(message['file'])}")
        return message
                
            