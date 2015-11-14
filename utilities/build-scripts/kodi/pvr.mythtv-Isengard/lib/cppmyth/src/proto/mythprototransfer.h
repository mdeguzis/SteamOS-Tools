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

#ifndef MYTHPROTOTRANSFER_H
#define	MYTHPROTOTRANSFER_H

#include "mythprotobase.h"

#define PROTO_TRANSFER_RCVBUF     64000

namespace Myth
{

  class ProtoTransfer;
  typedef MYTH_SHARED_PTR<ProtoTransfer> ProtoTransferPtr;

  class ProtoTransfer : public ProtoBase
  {
  public:
    ProtoTransfer(const std::string& server, unsigned port, const std::string& pathname, const std::string& sgname);

    virtual bool Open();
    virtual void Close();

    void Lock();
    void Unlock();
    bool TryLock();
    /**
     * @brief Flushing unread data previously requested
     * @return void
     */
    void Flush();

    uint32_t GetFileId() const;
    std::string GetPathName() const;
    std::string GetStorageGroupName() const;

    int64_t GetSize() const;
    int64_t GetPosition() const;
    int64_t GetRequested() const;
    int64_t GetRemaining() const;

    void SetSize(int64_t size);
    void SetPosition(int64_t position);
    void SetRequested(int64_t requested);

  private:
    int64_t m_fileSize;                 ///< Size of file
    int64_t m_filePosition;             ///< Current read position
    int64_t m_fileRequest;              ///< Current requested position
    uint32_t m_fileId;
    std::string m_pathName;
    std::string m_storageGroupName;

    bool Announce75();
  };

}

#endif	/* MYTHPROTOTRANSFER_H */
