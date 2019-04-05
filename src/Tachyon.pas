//
// Tachyon.pas
//
// Copyright (c) 2019 Matias Vara <matiasevara@gmail.com>
// All Rights Reserved
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

program Tachyon;

{$IFDEF FPC}
 {$mode delphi}
{$ENDIF}

{%RunCommand qemu-system-x86_64 -m 256 -smp 1 -drive format=raw,file=StaticWebServer.img -net nic,model=virtio -net tap,ifname=TAP2 -drive file=fat:rw:StaticWebServerFiles,if=none,id=drive-virtio-disk0 -device virtio-blk-pci,drive=drive-virtio-disk0,addr=06 -serial file:torodebug.txt}
{%RunFlags BUILD-}

uses
  Kernel in '..\torokernel\rtl\Kernel.pas',
  Process in '..\torokernel\rtl\Process.pas',
  Memory in '..\torokernel\rtl\Memory.pas',
  Debug in '..\torokernel\rtl\Debug.pas',
  Arch in '..\torokernel\rtl\Arch.pas',
  Filesystem in '..\torokernel\rtl\Filesystem.pas',
  Pci in '..\torokernel\rtl\drivers\Pci.pas',
  // Ide in '..\torokernel\rtl\drivers\IdeDisk.pas',
  VirtIOBlk in '..\torokernel\rtl\drivers\VirtIOBlk.pas',
  // Ext2 in '..\torokernel\rtl\drivers\Ext2.pas',
  Fat in '..\torokernel\rtl\drivers\Fat.pas',
  Console in '..\torokernel\rtl\drivers\Console.pas',
  Network in '..\torokernel\rtl\Network.pas',
  //E1000 in '..\torokernel\rtl\drivers\E1000.pas';
  VirtIONet in '..\torokernel\rtl\drivers\VirtIONet.pas';

const
  MaskIP: array[0..3] of Byte   = (255, 255, 255, 0);
  Gateway: array[0..3] of Byte  = (192, 100, 200, 1);
  DefaultLocalIP: array[0..3] of Byte  = (192, 100, 200, 100);

  HeaderOK = 'HTTP/1.0 200'#13#10'Content-type: Text/Html'#13#10 + 'Content-length:';
  ContentOK = #13#10'Connection: close'#13#10 + 'Server: ToroMicroserver'#13#10''#13#10;
  HeaderNotFound = 'HTTP/1.0 404'#13#10;
  SERVICE_TIMEOUT = 20000;
  Max_Path_Len = 200;

type
  PRequest = ^TRequest;
  TRequest = record
    BufferStart: pchar;
    BufferEnd: pchar;
    counter: Longint;
  end;

var
  HttpServer, HttpClient: PSocket;
  LocalIp: array[0..3] of Byte;
  tid: TThreadID;
  rq: PRequest;

type
  TBytes = array[0..0] of byte;
  PByte = ^TBytes;

const
  Base64EncodeChars: array[0..63] of Char = (
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', '+', '/');

  Base64DecodeChars: array[0..255] of LongInt = (
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1,
    -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
    -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);

procedure Base64Encode(Data: PByte; Len: LongInt; out Dest: PChar);
var
  R, I, J, L , C: Longint;
begin
  Dest := Nil;
  if Len = 0 then
    Exit;
  R := Len mod 3;
  Dec(Len, R);
  L := (Len div 3) * 4;
  if R > 0 then
    Inc(L, 4);
  I := 0;
  J := 0;
  Dest := ToroGetMem(L+1);
  If Dest = nil then
    Exit;
  while I < Len do
  begin
    C := Data[I];
    Inc(I);
    C := (C shl 8) or Data[I];
    Inc(I);
    C := (C shl 8) or Data[I];
    Inc(I);
    Dest[J] := Base64EncodeChars[C shr 18];
    Inc(J);
    Dest[J] := Base64EncodeChars[(C shr 12) and $3F];
    Inc(J);
    Dest[J] := Base64EncodeChars[(C shr 6) and $3F];
    Inc(J);
    Dest[J] := Base64EncodeChars[C and $3F];
    Inc(J);
  end;
  if R = 1 then
  begin
    C := Data[I];
    Dest[J] := Base64EncodeChars[C shr 2];
    Inc(J);
    Dest[J] := Base64EncodeChars[(C and $03) shl 4];
    Inc(J);
    Dest[J] := '=';
    Inc(J);
    Dest[J] := '=';
  end
  else if R = 2 then
  begin
    C := Data[I];
    Inc(I);
    C := (C shl 8) or Data[I];
    Dest[J] := Base64EncodeChars[C shr 10];
    Inc(J);
    Dest[J] := Base64EncodeChars[(C shr 4) and $3F];
    Inc(J);
    Dest[J] := Base64EncodeChars[(C and $0F) shl 2];
    Inc(J);
    Dest[J] := '=';
  end;
  Inc(J);
  Dest[J] := #0;
end;

function Base64Decode(Data: PChar; out Dest: PByte): LongInt;
var
  R, Len, I, J, L : Longint;
  B1, B2, B3, B4: LongInt;
begin
  Result := 0;
  Len := Length(Data);
  if (Len = 0) or (Len mod 4 > 0) then
    Exit;
  R := 0;
  if Data[Len - 1] = '=' then
    R := 1
  else if Data[Len] = '=' then
    R := 2;
  L := Len;
  if R > 0 then
    Dec(L, 4);
  L := (L div 4) * 3;
  Inc(L, R);
  Dest := ToroGetMem(L);
  if Dest = Nil then
    Exit;
  Result := L;
  I := 0;
  J := 0;
  while I <= Len do
  begin
    repeat
      B1 := Base64DecodeChars[Ord(Data[I])];
      Inc(I);
    until (I > Len) or (B1 <> -1);
    if B1 = -1 then
      Break;
    repeat
      B2 := Base64DecodeChars[Ord(Data[I])];
      Inc(I);
    until (I > Len) or (B2 <> -1);
    if B2 = -1 then
      Break;
    Dest[J] := Byte((B1 shl 2) or ((B2 and $30) shr 4));
    Inc(J);
    repeat
      if Data[I] = '=' then
        Exit;
      B3 := Base64DecodeChars[Ord(Data[I])];
      Inc(I);
    until (I > Len) or (B3 <> -1);
    if B3 = -1 then
      Break;
    Dest[J] := Byte(((B2 and $0F) shl 4) or ((B3 and $3C) shr 2));
    Inc(J);
    repeat
      if Data[I] = '=' then
        Exit;
      B4 := Base64DecodeChars[Ord(Data[I])];
      Inc(I);
    until ((I > Len) or (B4 <> -1));
    if B4 = -1 then
      Break;
    Dest[J] := Byte(((B3 and $03) shl 6) or B4);
    Inc(J);
  end;
end;

function GetRequest(Socket: PSocket): Boolean;
var
   i, Len: longint;
   buf: char;
   rq: PRequest;
   buffer: Pchar;
begin
  Result := False;
  rq := Socket.UserDefined;
  i := rq.counter;
  buffer := rq.BufferEnd;
  // Calculate len of the request
  if i <> 0 then
    Len :=  i - 3
  else
    Len := 0;
  while (SysSocketRecv(Socket, @buf,1,0) <> 0)do
  begin
    if ((i>3) and (buf = #32)) or (Len = Max_Path_Len) then
    begin
      buffer^ := #0;
      Result := True;
      Exit;
    end;
    if (i>3) then
    begin
      Len := i - 3;
      buffer^ := buf;
      Inc(buffer);
      Inc(rq.BufferEnd);
    end;
    Inc(i);
  end;
  rq.counter := i;
end;

procedure SendStream(Socket: Psocket; Stream: Pchar);
begin
  SysSocketSend(Socket, Stream, Length(Stream), 0);
end;

procedure ProcessRequest (Socket: PSocket; Answer: pchar);
var
  dst, tmp: ^char;
  anssizechar: array[0..10] of char;
  AnsSize: LongInt;
begin
  if Answer = nil then
  begin
    SendStream(Socket, HeaderNotFound);
  end
  else begin
    AnsSize := Strlen(Answer);
    InttoStr(AnsSize,@anssizechar[0]);
    dst := ToroGetMem(StrLen(@anssizechar[0]) + StrLen(HeaderOk) + StrLen(ContentOK) + StrLen(Answer));
    tmp := dst;
    StrConcat(HeaderOk, @anssizechar[0], dst);
    dst := dst + StrLen(@anssizechar[0]) + StrLen(HeaderOk);
    StrConcat(dst, ContentOK, dst);
    dst := dst + StrLen(ContentOK) ;
    StrConcat(dst, Answer, dst);
    SendStream(Socket,tmp);
    ToroFreeMem(tmp);
  end;
end;

function GetFileContent(entry: pchar): pchar;
var
  idx: TInode;
  indexSize: LongInt;
  Buf: Pchar;
  tmp: THandle;
begin
  Result := nil;
  if SysStatFile(entry, @idx) = 0 then
  begin
    WriteConsoleF ('%p not found\n',[PtrUInt(entry)]);
    Exit;
  end else
    Buf := ToroGetMem(idx.Size + 1);
  tmp := SysOpenFile(entry);
  if (tmp <> 0) then
  begin
    indexSize := SysReadFile(tmp, idx.Size, Buf);
    pchar(Buf+idx.Size)^ := #0;
    SysCloseFile(tmp);
    WriteConsoleF('\t /VWebServer/n: %p loaded, size: %d bytes\n', [PtrUInt(entry),idx.Size]);
    Result := Buf;
  end else
  begin
    WriteConsoleF ('index.html not found\n',[]);
  end;
end;

function ServiceReceive(Socket: PSocket): LongInt;
var
  rq: PRequest;
  entry, content: PChar;
begin
  while true do
  begin
    if GetRequest(Socket) then
    begin
      rq := Socket.UserDefined;
      entry := rq.BufferStart;
      content := GetFileContent(rq.BufferStart);
      ProcessRequest(Socket, content);
      SysSocketClose(Socket);
      if content <> nil then
        ToroFreeMem(content);
      ToroFreeMem(rq.BufferStart);
      ToroFreeMem(rq);
      Exit;
    end
    else
    begin
      if not SysSocketSelect(Socket, SERVICE_TIMEOUT) then
      begin
        SysSocketClose(Socket);
        rq := Socket.UserDefined;
        ToroFreeMem(rq.BufferStart);
        ToroFreeMem(rq);
        Exit;
      end;
    end;
  end;
  Result := 0;
end;

function ProcessesSocket(Socket: Pointer): PtrInt;
begin
  ServiceReceive (Socket);
  Result := 0;
end;

begin
  If GetKernelParam(1)^ = #0 then
  begin
    DedicateNetwork('virtionet', DefaultLocalIP, Gateway, MaskIP, nil)
  end else
  begin
    IPStrtoArray(GetKernelParam(1), LocalIp);
    DedicateNetwork('virtionet', LocalIP, Gateway, MaskIP, nil);
  end;

  DedicateBlockDriver('virtioblk', 0);

  //SysMount('ext2','ATA0',5);
  SysMount('fat', 'virtioblk', 0);

  HttpServer := SysSocket(SOCKET_STREAM);
  HttpServer.Sourceport := 80;
  HttpServer.Blocking := True;
  SysSocketListen(HttpServer, 50);
  WriteConsoleF('\t /VWebServer/n: listening ...\n',[]);

  while true do
  begin
    HttpClient := SysSocketAccept(HttpServer);
    rq := ToroGetMem(sizeof(TRequest));
    rq.BufferStart := ToroGetMem(Max_Path_Len);
    rq.BufferEnd := rq.BufferStart;
    rq.counter := 0;
    HttpClient.UserDefined := rq;
    tid := BeginThread(nil, 4096*2, ProcessesSocket, HttpClient, 0, tid);
  end;

end.
