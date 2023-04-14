timeout 1 bash -c "{ $(./decide.sh $1 server) goodconf; }" 1> server-capture &
timeout 1 bash -c "{ sleep 0.25; $(./decide.sh $1 client) 1235 Marcus; }" 1> client-capture;
