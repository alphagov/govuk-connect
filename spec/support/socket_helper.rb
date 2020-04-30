module SocketHelper
  def stub_socket_port_free(port)
    allow(cli).to receive(:rand).and_return(port)

    allow(Socket).to receive(:tcp)
      .with("127.0.0.1", port, connect_timeout: 0.1)
      .and_raise(Errno::ECONNREFUSED)
  end
end
