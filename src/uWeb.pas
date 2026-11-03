unit uWeb;

{ Halaman web di dalam aplikasi (mis. Exness web trading).
  Delphi 7 hanya punya komponen Internet Explorer yang tidak didukung web modern, jadi dipakai
  Microsoft Edge mode aplikasi (tanpa tab / address bar) dengan profil sendiri, lalu jendelanya
  ditanam (SetParent) ke panel aplikasi dan ikut ukuran panel. }

interface

uses Windows, Messages, SysUtils, Classes, Controls, ExtCtrls;

type
  TWebEmbed = class
  private
    FHost: TWinControl;
    FURL, FProfile: string;
    FPI: TProcessInformation;
    FWnd: HWND;
    FWndTid: DWORD;   { thread jendela Edge yang input-nya digabung dengan aplikasi }
    FTimer: TTimer;
    FWaitUntil: TDateTime;
    FOnStatus: TGetStrProc;
    procedure OnFind(Sender: TObject);
    procedure Status(const S: string);
  public
    constructor Create(Host: TWinControl; const URL, ProfileDir: string);
    destructor Destroy; override;
    { buka (atau tampilkan lagi bila sudah terbuka) }
    procedure Open;
    { tutup Edge yang ditanam; Open berikutnya membuka ulang }
    procedure Close;
    procedure Fit;
    function Running: Boolean;
    property OnStatus: TGetStrProc read FOnStatus write FOnStatus;
  end;

function EdgePath: string;

implementation

function EdgePath: string;
const Paths: array[0..1] of string = (
  'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  'C:\Program Files\Microsoft\Edge\Application\msedge.exe');
var i: Integer;
begin
  Result := '';
  for i := 0 to High(Paths) do
    if FileExists(Paths[i]) then begin Result := Paths[i]; Exit; end;
end;

type
  PFindRec = ^TFindRec;
  TFindRec = record
    Pid: DWORD;
    Wnd: HWND;
  end;

function EnumFind(h: HWND; L: LPARAM): BOOL; stdcall;
var pid: DWORD; cls: array[0..63] of Char;
begin
  Result := True;
  GetWindowThreadProcessId(h, @pid);
  if (pid <> PFindRec(L)^.Pid) or not IsWindowVisible(h) then Exit;
  GetClassName(h, cls, SizeOf(cls));
  if StrComp(cls, 'Chrome_WidgetWin_1') <> 0 then Exit;
  PFindRec(L)^.Wnd := h;
  Result := False;
end;

constructor TWebEmbed.Create(Host: TWinControl; const URL, ProfileDir: string);
begin
  inherited Create;
  FHost := Host;
  FURL := URL;
  FProfile := ProfileDir;
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := 250;
  FTimer.OnTimer := OnFind;
end;

destructor TWebEmbed.Destroy;
begin
  Close;
  FTimer.Free;
  inherited;
end;

procedure TWebEmbed.Status(const S: string);
begin
  if Assigned(FOnStatus) then FOnStatus(S);
end;

function TWebEmbed.Running: Boolean;
begin
  Result := (FWnd <> 0) and IsWindow(FWnd);
end;

procedure TWebEmbed.Open;
var si: TStartupInfo; cmd, exe: string;
begin
  if Running then begin Fit; Exit; end;
  if FTimer.Enabled then Exit;   { sedang membuka }
  Close;
  exe := EdgePath;
  if exe = '' then
  begin
    Status('Microsoft Edge tidak ditemukan - pakai tombol BUKA DI BROWSER.');
    Exit;
  end;
  ForceDirectories(FProfile);
  { profil sendiri = proses Edge sendiri, jendelanya bisa dicari lewat PID; mulai di luar layar }
  cmd := Format('"%s" --app="%s" --user-data-dir="%s" --no-first-run --no-default-browser-check ' +
    '--window-position=-3000,-3000 --window-size=1200,800', [exe, FURL, ExcludeTrailingPathDelimiter(FProfile)]);
  FillChar(si, SizeOf(si), 0);
  si.cb := SizeOf(si);
  if not CreateProcess(nil, PChar(cmd), nil, nil, False, 0, nil, nil, si, FPI) then
  begin
    Status('Gagal menjalankan Edge (kode ' + IntToStr(GetLastError) + ').');
    Exit;
  end;
  CloseHandle(FPI.hThread);
  FPI.hThread := 0;
  FWaitUntil := Now + 20 / 86400;
  Status('Membuka Exness ...');
  FTimer.Enabled := True;
end;

procedure TWebEmbed.OnFind(Sender: TObject);
var r: TFindRec; st: Longint;
begin
  r.Pid := FPI.dwProcessId;
  r.Wnd := 0;
  EnumWindows(@EnumFind, LPARAM(@r));
  if r.Wnd = 0 then
  begin
    if Now > FWaitUntil then
    begin
      FTimer.Enabled := False;
      Status('Jendela Edge tidak muncul - klik MUAT ULANG atau BUKA DI BROWSER.');
    end;
    Exit;
  end;
  FTimer.Enabled := False;
  FWnd := r.Wnd;
  { jadikan jendela anak tanpa bingkai di panel aplikasi }
  st := GetWindowLong(FWnd, GWL_STYLE);
  st := (st and not (WS_POPUP or WS_CAPTION or WS_THICKFRAME or WS_SYSMENU or WS_MINIMIZEBOX or WS_MAXIMIZEBOX)) or WS_CHILD;
  SetWindowLong(FWnd, GWL_STYLE, st);
  Windows.SetParent(FWnd, FHost.Handle);
  { gabungkan input Edge dengan aplikasi: satu fokus keyboard & satu kursor teks
    (kotak cari koin ATAU kolom di web, yang terakhir diklik pengguna) }
  FWndTid := GetWindowThreadProcessId(FWnd, nil);
  if (FWndTid <> 0) and not AttachThreadInput(GetCurrentThreadId, FWndTid, True) then FWndTid := 0;
  Fit;
  ShowWindow(FWnd, SW_SHOW);
  Status('');
end;

{ Edge menggambar title bar sendiri (tidak hilang walau gaya jendela diubah):
  digeser ke atas sejauh tingginya supaya yang terlihat hanya halaman web }
procedure TWebEmbed.Fit;
var cap: Integer; dc: HDC;
begin
  if not Running then Exit;
  dc := GetDC(0);
  cap := MulDiv(30, GetDeviceCaps(dc, LOGPIXELSY), 96);
  ReleaseDC(0, dc);
  MoveWindow(FWnd, 0, -cap, FHost.ClientWidth, FHost.ClientHeight + cap, True);
end;

procedure TWebEmbed.Close;
begin
  FTimer.Enabled := False;
  if FWndTid <> 0 then AttachThreadInput(GetCurrentThreadId, FWndTid, False);
  FWndTid := 0;
  if Running then PostMessage(FWnd, WM_CLOSE, 0, 0);
  if FPI.hProcess <> 0 then
  begin
    { beri waktu Edge menyimpan sesi login, lalu pastikan berhenti }
    if WaitForSingleObject(FPI.hProcess, 3000) = WAIT_TIMEOUT then TerminateProcess(FPI.hProcess, 0);
    CloseHandle(FPI.hProcess);
  end;
  FillChar(FPI, SizeOf(FPI), 0);
  FWnd := 0;
end;

end.
