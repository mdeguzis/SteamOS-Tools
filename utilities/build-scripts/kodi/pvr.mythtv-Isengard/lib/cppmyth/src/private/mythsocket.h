/*
 *      Copyright (C) 2014 Jean-Luc Barriere
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 *  MA 02110-1301 USA
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#ifndef MYTHSOCKET_H
#define	MYTHSOCKET_H

#include "os/os.h"

#include <cstddef>  // for size_t

#define SOCKET_HOSTNAME_MAXSIZE       1025
#define SOCKET_RCVBUF_MINSIZE         16384
#define SOCKET_READ_TIMEOUT_SEC       10
#define SOCKET_READ_TIMEOUT_USEC      0
#define SOCKET_READ_ATTEMPT           3

namespace Myth
{

  class TcpSocket
  {
  public:
    TcpSocket();
    ~TcpSocket();

    int GetErrNo() const
    {
      return m_errno;
    }
    bool Connect(const char *server, unsigned port, int rcvbuf);
    bool SendMessage(const char *msg, size_t size);
    void SetReadAttempt(int n)
    {
      m_attempt = n;
    }
    size_t ReadResponse(void *buf, size_t n);
    void Disconnect();
    bool IsValid() const
    {
      return (m_socket == INVALID_SOCKET_VALUE ? false : true);
    }
    bool IsConnected() const
    {
      return IsValid();
    }
    int Listen(timeval *timeout);
    tcp_socket_t GetSocket() const;

    static const char *GetMyHostName();

  private:
    tcp_socket_t m_socket;
    int m_rcvbuf;
    int m_errno;
    int m_attempt;

    // prevent copy
    TcpSocket(const TcpSocket&);
    TcpSocket& operator=(const TcpSocket&);
  };

}

#endif	/* MYTHSOCKET_H */
