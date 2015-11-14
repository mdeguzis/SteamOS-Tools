/*
 *      Copyright (C) 2015 Jean-Luc Barriere
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

#include "mythlocked.h"
#include "private/os/threads/mutex.h"

using namespace Myth;

namespace Myth
{
  struct LockGuard::Lockable
  {
    OS::CMutex mutex;
  };
}

LockGuard::LockGuard(Lockable* lock)
: m_lock(lock)
{
  m_lock->mutex.Lock();
}

LockGuard::~LockGuard()
{
  m_lock->mutex.Unlock();
}

LockGuard::Lockable* LockGuard::CreateLock()
{
  return new Lockable();
}

void LockGuard::DestroyLock(Lockable* lock)
{
  delete lock;
}

void LockGuard::Lock(Lockable* lock)
{
  lock->mutex.Lock();
}

void LockGuard::Unlock(Lockable* lock)
{
  lock->mutex.Unlock();
}

void LockGuard::ClearLock(Lockable* lock)
{
  lock->mutex.Clear();
}
