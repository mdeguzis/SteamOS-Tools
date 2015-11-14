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

#ifndef MYTHWSREQUEST_H
#define	MYTHWSREQUEST_H

#include "mythwscontent.h"

#include <cstddef>  // for size_t
#include <string>
#include <vector>

#define REQUEST_PROTOCOL      "HTTP/1.1"
#define REQUEST_USER_AGENT    "libcppmyth/1.0"
#define REQUEST_CONNECTION    "close" // "keep-alive"
#define REQUEST_STD_CHARSET   "utf-8"

namespace Myth
{

  typedef enum
  {
    HRM_GET,
    HRM_POST,
    HRM_HEAD,
  } HRM_t;

  class WSRequest
  {
  public:
    WSRequest(const std::string& server, unsigned port);
    ~WSRequest();

    void RequestService(const std::string& url, HRM_t method = HRM_GET);
    void RequestAccept(CT_t contentType);
    void SetContentParam(const std::string& param, const std::string& value);
    void SetContentCustom(CT_t contentType, const char *content);
    const std::string& GetContent() const { return m_contentData; }
    void ClearContent();

    void MakeMessage(std::string& msg) const
    {
      if (m_service_method == HRM_GET) MakeMessageGET(msg);
      else if (m_service_method == HRM_POST) MakeMessagePOST(msg);
      else if (m_service_method == HRM_HEAD) MakeMessageHEAD(msg);
    }

    const std::string& GetServer() const { return m_server; }
    unsigned GetPort() const { return m_port; }

  private:
    std::string m_server;
    unsigned m_port;
    std::string m_service_url;
    HRM_t m_service_method;
    std::string m_charset;
    CT_t m_accept;
    CT_t m_contentType;
    std::string m_contentData;

    void MakeMessageGET(std::string& msg) const;
    void MakeMessagePOST(std::string& msg) const;
    void MakeMessageHEAD(std::string& msg) const;
  };

}

#endif	/* MYTHWSREQUEST_H */
