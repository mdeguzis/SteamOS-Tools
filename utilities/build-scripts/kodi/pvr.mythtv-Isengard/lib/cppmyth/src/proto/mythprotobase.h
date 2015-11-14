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

#ifndef MYTHPROTOBASE_H
#define	MYTHPROTOBASE_H

#include "../mythtypes.h"

#include <string>

#define PROTO_BUFFER_SIZE         4000
#define PROTO_SENDMSG_MAXSIZE     64000
#define PROTO_STR_SEPARATOR       "[]:[]"
#define PROTO_STR_SEPARATOR_LEN   (sizeof(PROTO_STR_SEPARATOR) - 1)

namespace Myth
{

  namespace OS
  {
    class CMutex;
  }

  class TcpSocket;

  class ProtoBase
  {
  public:
    ProtoBase(const std::string& server, unsigned port);
    virtual ~ProtoBase();

    typedef enum
    {
      ERROR_NO_ERROR = 0,
      ERROR_SERVER_UNREACHABLE,
      ERROR_SOCKET_ERROR,
      ERROR_UNKNOWN_VERSION,
    } ERROR_t;

    virtual bool Open() = 0;
    virtual void Close();
    virtual bool IsOpen() { return m_isOpen; }
    virtual unsigned GetProtoVersion() const;
    virtual std::string GetServer() const;
    virtual unsigned GetPort() const;
    virtual int GetSocketErrNo() const;
    virtual int GetSocket() const;
    virtual bool HasHanging() const;
    virtual void CleanHanging();
    virtual ERROR_t GetProtoError() const;

  protected:
    OS::CMutex *m_mutex;
    TcpSocket *m_socket;
    unsigned m_protoVersion;
    std::string m_server;
    unsigned m_port;
    bool m_hang;                  ///< Connection hang: while true allow retry
    bool m_tainted;               ///< Connection has hung since last reset
    size_t m_msgLength;
    size_t m_msgConsumed;

    bool OpenConnection(int rcvbuf);
    void HangException();
    bool SendCommand(const char *cmd, bool feedback = true);
    size_t GetMessageLength() const;
    bool ReadField(std::string& field);
    bool IsMessageOK(const std::string& field) const;
    size_t FlushMessage();
    bool RcvMessageLength();

    ProgramPtr RcvProgramInfo()
    {
      if (m_protoVersion >= 86) return RcvProgramInfo86();
      if (m_protoVersion >= 82) return RcvProgramInfo82();
      if (m_protoVersion >= 79) return RcvProgramInfo79();
      if (m_protoVersion >= 76) return RcvProgramInfo76();
      return RcvProgramInfo75();
    }

    void MakeProgramInfo(const Program& program, std::string& msg)
    {
      if (m_protoVersion >= 86) MakeProgramInfo86(program, msg);
      else if (m_protoVersion >= 82) MakeProgramInfo82(program, msg);
      else if (m_protoVersion >= 79) MakeProgramInfo79(program, msg);
      else if (m_protoVersion >= 76) MakeProgramInfo76(program, msg);
      else MakeProgramInfo75(program, msg);
    }

  private:
    bool m_isOpen;
    ERROR_t m_protoError;

    bool RcvVersion(unsigned *version);

    ProgramPtr RcvProgramInfo75();
    ProgramPtr RcvProgramInfo76();
    ProgramPtr RcvProgramInfo79();
    ProgramPtr RcvProgramInfo82();
    ProgramPtr RcvProgramInfo86();
    void MakeProgramInfo75(const Program& program, std::string& msg);
    void MakeProgramInfo76(const Program& program, std::string& msg);
    void MakeProgramInfo79(const Program& program, std::string& msg);
    void MakeProgramInfo82(const Program& program, std::string& msg);
    void MakeProgramInfo86(const Program& program, std::string& msg);

  };

}

#endif	/* MYTHPROTOBASE_H */
