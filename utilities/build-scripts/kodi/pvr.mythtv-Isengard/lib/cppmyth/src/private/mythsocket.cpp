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

#include "mythsocket.h"
#include "../mythdebug.h"

#include <errno.h>
#include <cstdio>
#include <cstring>

#ifdef __WINDOWS__
#include <Ws2tcpip.h>
#define SHUT_RDWR SD_BOTH
#define SHUT_WR   SD_SEND
#define LASTERROR WSAGetLastError()
typedef int socklen_t;
#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#define closesocket(a) close(a)
#define LASTERROR errno
#endif /* __WINDOWS__ */

#include <signal.h>

using namespace Myth;

static char my_hostname[SOCKET_HOSTNAME_MAXSIZE];
static volatile tcp_socket_t my_socket;

static void __sigHandler(int sig)
{
  closesocket(my_socket);
  my_socket = INVALID_SOCKET_VALUE;
  (void)sig;
}

TcpSocket::TcpSocket()
: m_socket(INVALID_SOCKET_VALUE)
, m_rcvbuf(SOCKET_RCVBUF_MINSIZE)
, m_errno(0)
, m_attempt(SOCKET_READ_ATTEMPT)
{
}

TcpSocket::~TcpSocket()
{
  if (IsConnected())
    Disconnect();
}

static int __connectAddr(struct addrinfo *addr, tcp_socket_t *s, int rcvbuf)
{
#ifndef __WINDOWS__
  void (*old_sighandler)(int);
  int old_alarm;
#endif
  socklen_t size;
  int err = 0, opt_rcvbuf;

  if ((my_hostname[0] == '\0') && (gethostname(my_hostname, sizeof (my_hostname)) < 0))
  {
    err = LASTERROR;
    DBG(MYTH_DBG_ERROR, "%s: gethostname failed (%d)\n", __FUNCTION__, err);
    return err;
  }

  *s = socket(addr->ai_family, addr->ai_socktype, addr->ai_protocol);
  if (*s == INVALID_SOCKET_VALUE)
  {
    err = LASTERROR;
    DBG(MYTH_DBG_ERROR, "%s: invalid socket (%d)\n", __FUNCTION__, err);
    return err;
  }

  opt_rcvbuf = (rcvbuf < SOCKET_RCVBUF_MINSIZE ? SOCKET_RCVBUF_MINSIZE : rcvbuf);
  size = sizeof (opt_rcvbuf);
  if (setsockopt(*s, SOL_SOCKET, SO_RCVBUF, (char *)&opt_rcvbuf, size))
    DBG(MYTH_DBG_WARN, "%s: could not set rcvbuf from socket (%d)\n", __FUNCTION__, LASTERROR);
  if (getsockopt(*s, SOL_SOCKET, SO_RCVBUF, (char *)&opt_rcvbuf, &size))
    DBG(MYTH_DBG_WARN, "%s: could not get rcvbuf from socket (%d)\n", __FUNCTION__, LASTERROR);

#ifndef __WINDOWS__
  old_sighandler = signal(SIGALRM, __sigHandler);
  old_alarm = alarm(5);
#endif
  my_socket = *s;
  if (connect(*s, addr->ai_addr, addr->ai_addrlen) < 0)
  {
    err = LASTERROR;
    DBG(MYTH_DBG_ERROR, "%s: failed to connect (%d)\n", __FUNCTION__, err);
    closesocket(*s);
#ifndef __WINDOWS__
    signal(SIGALRM, old_sighandler);
    alarm(old_alarm);
#endif
    return err;
  }
  my_socket = INVALID_SOCKET_VALUE;
#ifndef __WINDOWS__
  signal(SIGALRM, old_sighandler);
  alarm(old_alarm);
#endif
  DBG(MYTH_DBG_DEBUG, "%s: connected to socket(%p)\n", __FUNCTION__, s);
  return err;
}

bool TcpSocket::Connect(const char *server, unsigned port, int rcvbuf)
{
  struct addrinfo hints;
  struct addrinfo *result, *addr;
  char service[33];
  int err;

  if (IsConnected())
    Disconnect();

  if (rcvbuf > SOCKET_RCVBUF_MINSIZE)
    m_rcvbuf = rcvbuf;

  memset(&hints, 0, sizeof (hints));
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;
  sprintf(service, "%u", port);

  err = getaddrinfo(server, service, &hints, &result);
  if (err)
  {
    switch (err)
    {
      case EAI_NONAME:
        DBG(MYTH_DBG_ERROR, "%s: the specified host is unknown\n", __FUNCTION__);
        break;
      case EAI_FAIL:
        DBG(MYTH_DBG_ERROR, "%s: a non-recoverable failure in name resolution occurred\n", __FUNCTION__);
        break;
      case EAI_MEMORY:
        DBG(MYTH_DBG_ERROR, "%s: a memory allocation failure occurred\n", __FUNCTION__);
        break;
      case EAI_AGAIN:
        DBG(MYTH_DBG_ERROR, "%s: a temporary error occurred on an authoritative name server\n", __FUNCTION__);
        break;
      default:
        DBG(MYTH_DBG_ERROR, "%s: unknown error %d\n", __FUNCTION__, err);
        break;
    }
    m_errno = err;
    return false;
  }

  for (addr = result; addr; addr = addr->ai_next)
  {
    err = __connectAddr(addr, &m_socket, m_rcvbuf);
    if (!err)
      break;
  }
  freeaddrinfo(result);
  m_errno = err;
  return (err ? false : true);
}

bool TcpSocket::SendMessage(const char *msg, size_t size)
{
  if (IsValid())
  {
    size_t s = send(m_socket, msg, size, 0);
    if (s != size)
    {
      m_errno = LASTERROR;
      return false;
    }
    m_errno = 0;
    return true;
  }
  m_errno = ENOTCONN;
  return false;
}

size_t TcpSocket::ReadResponse(void *buf, size_t n)
{
  if (IsValid())
  {
    char *p = (char *)buf;
    struct timeval tv;
    fd_set fds;
    int r = 0, hangcount = 0;
    size_t rcvlen = 0;

    m_errno = 0;

    while (n > 0)
    {
      tv.tv_sec = SOCKET_READ_TIMEOUT_SEC;
      tv.tv_usec = SOCKET_READ_TIMEOUT_USEC;
      FD_ZERO(&fds);
      FD_SET(m_socket, &fds);
      r = select(m_socket + 1, &fds, NULL, NULL, &tv);
      if (r > 0)
        r = recv(m_socket, p, n, 0);
      if (r == 0)
      {
        DBG(MYTH_DBG_WARN, "%s: socket(%p) timed out (%d)\n", __FUNCTION__, &m_socket, hangcount);
        m_errno = ETIMEDOUT;
        if (++hangcount >= m_attempt)
          break;
      }
      if (r < 0)
      {
        m_errno = LASTERROR;
        break;
      }
      rcvlen += r;
      n -= r;
      p += r;
    }
    return rcvlen;
  }
  m_errno = ENOTCONN;
  return 0;
}

void TcpSocket::Disconnect()
{
  if (IsValid())
  {
    char buf[256];
    struct timeval tv;
    fd_set fds;
    int r = 0;

    shutdown(m_socket, SHUT_RDWR);

    tv.tv_sec = 5;
    tv.tv_usec = 0;
    do
    {
      FD_ZERO(&fds);
      FD_SET(m_socket, &fds);
      r = select(m_socket + 1, &fds, NULL, NULL, &tv);
      if (r > 0)
        r = recv(m_socket, buf, sizeof(buf), 0);
    } while (r > 0);

    closesocket(m_socket);
    m_socket = INVALID_SOCKET_VALUE;
  }
}

const char *TcpSocket::GetMyHostName()
{
  return my_hostname;
}

int TcpSocket::Listen(timeval *timeout)
{
  if (IsValid())
  {
    fd_set fds;
    int r;

    FD_ZERO(&fds);
    FD_SET(m_socket, &fds);
    r = select(m_socket + 1, &fds, NULL, NULL, timeout);
    if (r < 0)
      m_errno = LASTERROR;
    return r;
  }
  m_errno = ENOTCONN;
  return -1;
}

tcp_socket_t TcpSocket::GetSocket() const
{
  return m_socket;
}
