unit uCctv;

{ Kamera CCTV PH: 4 kamera IP / WiFi (RTSP) untuk pantau ruangan.
  - tiap kamera dibaca thread sendiri lewat Media Foundation (decode H.264 -> RGB32)
  - tampilan grid 2x2 gaya NVR: nama kamera, indikator LIVE, jam, status; klik ganda = layar penuh
  - otomatis menyambung ulang bila stream putus
  - pengaturan (nama, alamat RTSP, user, password) disimpan di cctv.ini }

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ExtCtrls, StdCtrls, Math, uUI, uMF;

type
  { bingkai terakhir sebuah kamera, ditulis thread dan dibaca saat menggambar }
  TCamFrame = class
  public
    CS: TRTLCriticalSection;
    Bits: Pointer;
    Size, W, H: Integer;
    BottomUp: Boolean;
    Seq: Integer;
    Status: string;
    Live: Boolean;
    LastFrame: TDateTime;
    constructor Create;
  end;

  TCamThread = class(TThread)
  private
    FURL: string;
    FFrame: TCamFrame;
    procedure SetStatus(const S: string; ALive: Boolean);
  protected
    procedure Execute; override;
  public
    constructor Create(const AURL: string; AFrame: TCamFrame);
  end;

  TCctvView = class(TPanel)
  private
    FGrid: TPanel;
    FLblInfo: TLabel;
    FTiles: array[0..3] of TPaintBox;
    FFrames: array[0..3] of TCamFrame;
    FThreads: array[0..3] of TCamThread;
    FSeen: array[0..3] of Integer;
    FFull: Integer;
    FTimer: TTimer;
    FLastSec: Integer;
    FIni: string;
    procedure LayoutTiles(Sender: TObject);
    procedure TilePaint(Sender: TObject);
    procedure TileDblClick(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure BtnSettings(Sender: TObject);
    procedure BtnClose(Sender: TObject);
    procedure StopAll;
    procedure StartAll;
  public
    Names, URLs, Users, Pass: array[0..3] of string;
    Enabled_: array[0..3] of Boolean;
    OnCloseView: TNotifyEvent;
    procedure Setup(const IniFile: string);
    procedure LoadCfg;
    procedure SaveCfg;
    procedure OpenView;
    procedure CloseView;
    function ShowSettings: Boolean;
    function FullURL(i: Integer): string;
  end;

implementation

const
  BrandNames: array[0..5] of string = ('Hikvision', 'Dahua / Imou', 'TP-Link Tapo', 'Ezviz', 'V380', 'Lainnya');
  BrandPaths: array[0..5] of string = ('/Streaming/Channels/102', '/cam/realmonitor?channel=1&subtype=1',
    '/stream2', '/h264/ch1/sub/av_stream', '/live/ch00_1', '/');

{ ---------------- TCamFrame / TCamThread ---------------- }

constructor TCamFrame.Create;
begin
  inherited Create;
  InitializeCriticalSection(CS);
  Status := 'Belum diatur';
end;

constructor TCamThread.Create(const AURL: string; AFrame: TCamFrame);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FURL := AURL;
  FFrame := AFrame;
  Resume;
end;

procedure TCamThread.SetStatus(const S: string; ALive: Boolean);
begin
  EnterCriticalSection(FFrame.CS);
  try
    FFrame.Status := S;
    FFrame.Live := ALive;
  finally
    LeaveCriticalSection(FFrame.CS);
  end;
end;

procedure TCamThread.Execute;
var
  attr: IMFAttributes;
  rd: IMFSourceReader;
  mt, cur: IMFMediaType;
  smp: IMFSample;
  buf: IMFMediaBuffer;
  flags, idx, len, maxLen, strideU: DWORD;
  ts, fs: Int64;
  w, h, stride, i, wait: Integer;
  p: Pointer;
  hr: HResult;
  wasLive: Boolean;

  function ReadSize: Boolean;
  begin
    Result := False;
    cur := nil;
    if Failed(rd.GetCurrentMediaType(MF_SOURCE_READER_FIRST_VIDEO_STREAM, cur)) then Exit;
    if Failed(cur.GetUINT64(MF_MT_FRAME_SIZE, fs)) then Exit;
    w := Integer(fs shr 32);
    h := Integer(fs and $FFFFFFFF);
    { stride negatif = gambar bottom-up }
    stride := w * 4;
    if Succeeded(cur.GetUINT32(MF_MT_DEFAULT_STRIDE, strideU)) then stride := Integer(strideU);
    Result := (w > 0) and (h > 0);
  end;

begin
  if (not MFAvailable) or (not Assigned(MFCreateSourceReaderFromURL)) then
  begin
    SetStatus('Media Foundation tidak tersedia di Windows ini', False);
    Exit;
  end;
  CoInitializeEx_(nil, COINIT_MULTITHREADED_);
  MFStartup(MF_VERSION, MFSTARTUP_FULL);
  try
    while not Terminated do
    begin
      SetStatus('Menghubungkan...', False);
      wasLive := False;
      rd := nil; attr := nil;
      MFCreateAttributes(attr, 3);
      attr.SetUINT32(MF_SOURCE_READER_ENABLE_ADVANCED_VIDEO_PROCESSING, 1);
      attr.SetUINT32(MF_LOW_LATENCY, 1);
      hr := MFCreateSourceReaderFromURL(PWideChar(WideString(FURL)), attr, rd);
      if Succeeded(hr) then
      begin
        rd.SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS, False);
        rd.SetStreamSelection(MF_SOURCE_READER_FIRST_VIDEO_STREAM, True);
        MFCreateMediaType(mt);
        mt.SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
        mt.SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
        hr := rd.SetCurrentMediaType(MF_SOURCE_READER_FIRST_VIDEO_STREAM, nil, mt);
        if Succeeded(hr) and not ReadSize then hr := E_FAIL;
      end;
      if Succeeded(hr) then
      begin
        while not Terminated do
        begin
          smp := nil; flags := 0;
          hr := rd.ReadSample(MF_SOURCE_READER_FIRST_VIDEO_STREAM, 0, @idx, @flags, @ts, smp);
          if Failed(hr) or ((flags and (MF_SOURCE_READERF_ERROR or MF_SOURCE_READERF_ENDOFSTREAM)) <> 0) then Break;
          if (flags and MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) <> 0 then ReadSize;
          if smp = nil then Continue;
          buf := nil;
          if Succeeded(smp.ConvertToContiguousBuffer(buf)) and Succeeded(buf.Lock(p, @maxLen, @len)) then
          try
            i := Abs(stride) * h;
            if Integer(len) >= i then
            begin
              EnterCriticalSection(FFrame.CS);
              try
                if FFrame.Size < i then
                begin
                  ReallocMem(FFrame.Bits, i);
                  FFrame.Size := i;
                end;
                Move(p^, FFrame.Bits^, i);
                FFrame.W := w;
                FFrame.H := h;
                FFrame.BottomUp := stride < 0;
                Inc(FFrame.Seq);
                FFrame.LastFrame := Now;
                FFrame.Live := True;
                FFrame.Status := 'LIVE';
              finally
                LeaveCriticalSection(FFrame.CS);
              end;
              wasLive := True;
            end;
          finally
            buf.Unlock;
          end;
          buf := nil; smp := nil;
        end;
      end;
      rd := nil; cur := nil; mt := nil; attr := nil;
      if Terminated then Break;
      if wasLive then SetStatus('Terputus - menyambung ulang...', False)
      else SetStatus(Format('Tidak bisa terhubung (kode %.8x) - periksa alamat / user / password', [hr]), False);
      { coba lagi 5 detik kemudian }
      for wait := 1 to 50 do
        if Terminated then Break else Sleep(100);
    end;
  finally
    rd := nil;
    MFShutdown;
    CoUninitialize_;
  end;
end;

{ ---------------- TCctvView ---------------- }

function UrlEnc(const S: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    if S[i] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~'] then Result := Result + S[i]
    else Result := Result + '%' + IntToHex(Ord(S[i]), 2);
end;

{ alamat lengkap: rtsp://user:password@ip:port/path (password di-encode) }
function TCctvView.FullURL(i: Integer): string;
var u: string; p: Integer;
begin
  u := Trim(URLs[i]);
  Result := u;
  if (Users[i] = '') or (Pos('@', u) > 0) then Exit;
  p := Pos('://', u);
  if p = 0 then Exit;
  Result := Copy(u, 1, p + 2) + UrlEnc(Users[i]) + ':' + UrlEnc(Pass[i]) + '@' + Copy(u, p + 3, MaxInt);
end;

procedure TCctvView.Setup(const IniFile: string);
var bar, r: TPanel; i: Integer;
begin
  FIni := IniFile;
  FFull := -1;
  BevelOuter := bvNone;
  Color := RGB(6, 8, 10);
  ParentBackground := False;

  bar := MakePanel(Self, alTop, 38, clrPanel2);
  MakeLabel(bar, 'KAMERA CCTV PH', 10, 4, clrYellow, 12, True);
  FLblInfo := MakeLabel(bar, '', 10, 22, clrMuted, 7);
  r := MakePanel(bar, alRight, 330, clrPanel2);
  with MakeBtn(r, 'PENGATURAN KAMERA', 6, 6, 150, 26, BtnSettings) do
  begin
    Bg := clrBlue; Fg := clWhite; Bold := True;
  end;
  with MakeBtn(r, 'X  TUTUP', 162, 6, 160, 26, BtnClose) do
  begin
    Bg := clrRed; Fg := clWhite; Bold := True;
  end;

  FGrid := MakePanel(Self, alClient, 0, RGB(6, 8, 10));
  FGrid.DoubleBuffered := True;
  FGrid.OnResize := LayoutTiles;
  for i := 0 to 3 do
  begin
    FFrames[i] := TCamFrame.Create;
    FTiles[i] := TPaintBox.Create(Self);
    FTiles[i].Parent := FGrid;
    FTiles[i].Tag := i;
    FTiles[i].OnPaint := TilePaint;
    FTiles[i].OnDblClick := TileDblClick;
    FTiles[i].Cursor := crHandPoint;
  end;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 66;
  FTimer.Enabled := False;
  FTimer.OnTimer := TimerTick;
  LoadCfg;
end;

procedure TCctvView.LoadCfg;
var sl: TStringList; i: Integer; k: string;
begin
  sl := TStringList.Create;
  try
    if FileExists(FIni) then sl.LoadFromFile(FIni);
    for i := 0 to 3 do
    begin
      k := 'CAM' + IntToStr(i + 1) + '_';
      Names[i] := sl.Values[k + 'NAMA'];
      if Names[i] = '' then Names[i] := 'Kamera ' + IntToStr(i + 1);
      URLs[i] := sl.Values[k + 'URL'];
      Users[i] := sl.Values[k + 'USER'];
      Pass[i] := sl.Values[k + 'PASS'];
      Enabled_[i] := sl.Values[k + 'AKTIF'] <> '0';
    end;
  finally
    sl.Free;
  end;
end;

procedure TCctvView.SaveCfg;
var sl: TStringList; i: Integer; k: string;
begin
  sl := TStringList.Create;
  try
    for i := 0 to 3 do
    begin
      k := 'CAM' + IntToStr(i + 1) + '_';
      sl.Values[k + 'NAMA'] := Names[i];
      sl.Values[k + 'URL'] := URLs[i];
      sl.Values[k + 'USER'] := Users[i];
      sl.Values[k + 'PASS'] := Pass[i];
      sl.Values[k + 'AKTIF'] := IntToStr(Ord(Enabled_[i]));
    end;
    try
      sl.SaveToFile(FIni);
    except
    end;
  finally
    sl.Free;
  end;
end;

procedure TCctvView.StartAll;
var i, n: Integer;
begin
  StopAll;
  n := 0;
  for i := 0 to 3 do
  begin
    EnterCriticalSection(FFrames[i].CS);
    FFrames[i].Live := False;
    FFrames[i].W := 0;
    if Trim(URLs[i]) = '' then FFrames[i].Status := 'Belum diatur - klik PENGATURAN KAMERA'
    else if not Enabled_[i] then FFrames[i].Status := 'Kamera dimatikan'
    else FFrames[i].Status := 'Menghubungkan...';
    LeaveCriticalSection(FFrames[i].CS);
    if (Trim(URLs[i]) <> '') and Enabled_[i] then
    begin
      FThreads[i] := TCamThread.Create(FullURL(i), FFrames[i]);
      Inc(n);
    end;
  end;
  FLblInfo.Caption := Format('%d dari 4 kamera aktif  ' + #149 + '  klik ganda kamera = layar penuh  ' + #149 +
    '  stream RTSP via Windows Media Foundation', [n]);
end;

{ thread dihentikan tanpa ditunggu (stream RTSP bisa lambat merespons) }
procedure TCctvView.StopAll;
var i: Integer;
begin
  for i := 0 to 3 do
    if FThreads[i] <> nil then
    begin
      FThreads[i].Terminate;
      FThreads[i] := nil;
    end;
end;

procedure TCctvView.OpenView;
begin
  Visible := True;
  BringToFront;
  StartAll;
  LayoutTiles(nil);
  FTimer.Enabled := True;
end;

procedure TCctvView.CloseView;
begin
  FTimer.Enabled := False;
  StopAll;
  Visible := False;
end;

procedure TCctvView.BtnClose(Sender: TObject);
begin
  CloseView;
  if Assigned(OnCloseView) then OnCloseView(Self);
end;

procedure TCctvView.LayoutTiles(Sender: TObject);
const G = 4;
var i, w, h: Integer;
begin
  w := (FGrid.ClientWidth - 3 * G) div 2;
  h := (FGrid.ClientHeight - 3 * G) div 2;
  for i := 0 to 3 do
  begin
    FTiles[i].Visible := (FFull < 0) or (FFull = i);
    if FFull = i then FTiles[i].SetBounds(G, G, FGrid.ClientWidth - 2 * G, FGrid.ClientHeight - 2 * G)
    else FTiles[i].SetBounds(G + (i mod 2) * (w + G), G + (i div 2) * (h + G), w, h);
  end;
end;

procedure TCctvView.TileDblClick(Sender: TObject);
var i: Integer;
begin
  i := TPaintBox(Sender).Tag;
  if FFull = i then FFull := -1 else FFull := i;
  LayoutTiles(nil);
  FGrid.Invalidate;
end;

procedure TCctvView.TimerTick(Sender: TObject);
var i, s: Integer; tick: Boolean;
begin
  s := Trunc(Now * 86400);
  tick := s <> FLastSec;   { jam di layar diperbarui tiap detik }
  FLastSec := s;
  for i := 0 to 3 do
    if tick or (FFrames[i].Seq <> FSeen[i]) then
    begin
      FSeen[i] := FFrames[i].Seq;
      if FTiles[i].Visible then FTiles[i].Invalidate;
    end;
end;

procedure TCctvView.TilePaint(Sender: TObject);
var pb: TPaintBox; cv: TCanvas; i, dw, dh, x, y: Integer; R, img: TRect; bi: TBitmapInfo;
    live, hasImg: Boolean; st, s: string; sc: Double;
begin
  pb := TPaintBox(Sender);
  i := pb.Tag;
  cv := pb.Canvas;
  R := pb.ClientRect;
  cv.Brush.Color := RGB(14, 16, 20);
  cv.FillRect(R);
  hasImg := False;

  EnterCriticalSection(FFrames[i].CS);
  try
    live := FFrames[i].Live and (Now - FFrames[i].LastFrame < 5 / 86400);
    st := FFrames[i].Status;
    if (FFrames[i].W > 0) and (FFrames[i].Bits <> nil) then
    begin
      { gambar menyesuaikan kotak, rasio tetap }
      sc := Min(R.Right / FFrames[i].W, R.Bottom / FFrames[i].H);
      dw := Round(FFrames[i].W * sc); dh := Round(FFrames[i].H * sc);
      img := Rect((R.Right - dw) div 2, (R.Bottom - dh) div 2, (R.Right - dw) div 2 + dw, (R.Bottom - dh) div 2 + dh);
      FillChar(bi, SizeOf(bi), 0);
      bi.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
      bi.bmiHeader.biWidth := FFrames[i].W;
      if FFrames[i].BottomUp then bi.bmiHeader.biHeight := FFrames[i].H else bi.bmiHeader.biHeight := -FFrames[i].H;
      bi.bmiHeader.biPlanes := 1;
      bi.bmiHeader.biBitCount := 32;
      bi.bmiHeader.biCompression := BI_RGB;
      SetStretchBltMode(cv.Handle, HALFTONE);
      SetBrushOrgEx(cv.Handle, 0, 0, nil);
      StretchDIBits(cv.Handle, img.Left, img.Top, dw, dh, 0, 0, FFrames[i].W, FFrames[i].H,
        FFrames[i].Bits, bi, DIB_RGB_COLORS, SRCCOPY);
      hasImg := True;
      if not live then
      begin
        { gambar terakhir diredupkan saat kamera terputus }
        cv.Brush.Style := bsClear;
      end;
    end;
  finally
    LeaveCriticalSection(FFrames[i].CS);
  end;

  cv.Brush.Style := bsClear;
  cv.Font.Name := 'Segoe UI';

  { nama kamera (kiri atas) }
  cv.Font.Size := 10; cv.Font.Style := [fsBold];
  s := Format('CAM %d  ' + #149 + '  %s', [i + 1, Names[i]]);
  cv.Brush.Style := bsSolid; cv.Brush.Color := RGB(0, 0, 0);
  cv.FillRect(Rect(8, 8, 20 + cv.TextWidth(s), 30));
  cv.Brush.Style := bsClear; cv.Font.Color := clWhite;
  cv.TextOut(14, 10, s);

  { indikator LIVE / OFFLINE (kanan atas) }
  cv.Font.Size := 9;
  if live then s := 'LIVE' else s := 'OFFLINE';
  x := R.Right - cv.TextWidth(s) - 36;
  cv.Brush.Style := bsSolid; cv.Brush.Color := RGB(0, 0, 0);
  cv.FillRect(Rect(x - 6, 8, R.Right - 8, 30));
  if live then
  begin
    if (Trunc(Now * 86400) mod 2 = 0) then cv.Brush.Color := RGB(255, 40, 40) else cv.Brush.Color := RGB(150, 20, 20);
    cv.Pen.Color := cv.Brush.Color;
    cv.Ellipse(x, 13, x + 12, 25);
    cv.Font.Color := RGB(255, 80, 80);
  end
  else
  begin
    cv.Brush.Color := RGB(110, 110, 110); cv.Pen.Color := cv.Brush.Color;
    cv.Ellipse(x, 13, x + 12, 25);
    cv.Font.Color := RGB(170, 170, 170);
  end;
  cv.Brush.Style := bsClear;
  cv.TextOut(x + 18, 10, s);

  { tanggal & jam (kiri bawah), seperti NVR }
  cv.Font.Size := 10; cv.Font.Style := [fsBold];
  s := FormatDateTime('dd/mm/yyyy  hh:nn:ss', Now);
  y := R.Bottom - 30;
  cv.Font.Color := RGB(0, 0, 0); cv.TextOut(15, y + 1, s);
  cv.Font.Color := clWhite; cv.TextOut(14, y, s);

  { status di tengah bila belum ada gambar / terputus }
  if (not hasImg) or (not live) then
  begin
    cv.Font.Size := 10; cv.Font.Style := [fsBold];
    if live then cv.Font.Color := clWhite else cv.Font.Color := RGB(255, 170, 0);
    if st = 'LIVE' then st := 'Menunggu gambar...';
    if (not hasImg) and (Trim(URLs[i]) = '') then st := 'Belum diatur - klik PENGATURAN KAMERA';
    cv.TextOut((R.Right - cv.TextWidth(st)) div 2, R.Bottom div 2 - 8, st);
  end;

  { bingkai tipis }
  cv.Brush.Style := bsClear;
  if live then cv.Pen.Color := RGB(40, 60, 40) else cv.Pen.Color := RGB(50, 50, 55);
  cv.Rectangle(R.Left, R.Top, R.Right, R.Bottom);
  cv.Brush.Style := bsSolid;
end;

{ ---------------- Pengaturan kamera ---------------- }

type
  TCamSetForm = class(TForm)
  public
    edName, edURL, edUser, edPass: array[0..3] of TEdit;
    cbOn: array[0..3] of TCheckBox;
    cbBrand: array[0..3] of TComboBox;
    procedure BrandChange(Sender: TObject);
  end;

procedure TCamSetForm.BrandChange(Sender: TObject);
var i, b, p: Integer; host, u: string;
begin
  i := TComboBox(Sender).Tag;
  b := TComboBox(Sender).ItemIndex;
  if b < 0 then Exit;
  { pertahankan IP/port yang sudah diketik, ganti path sesuai merek }
  u := Trim(edURL[i].Text);
  host := '192.168.1.100:554';
  p := Pos('://', u);
  if p > 0 then
  begin
    host := Copy(u, p + 3, MaxInt);
    if Pos('@', host) > 0 then Delete(host, 1, Pos('@', host));
    if Pos('/', host) > 0 then host := Copy(host, 1, Pos('/', host) - 1);
    if host = '' then host := '192.168.1.100:554';
  end;
  edURL[i].Text := 'rtsp://' + host + BrandPaths[b];
  if (b = 3) and (edUser[i].Text = '') then edUser[i].Text := 'admin';
end;

function TCctvView.ShowSettings: Boolean;
var f: TCamSetForm; i, y: Integer; m: TMemo;

  function Ed(Parent: TWinControl; X, W: Integer; const T: string): TEdit;
  begin
    Result := TEdit.Create(f);
    Result.Parent := Parent;
    Result.SetBounds(X, y, W, 22);
    Result.Color := clrPanel2;
    Result.Font.Color := clrText;
    Result.Text := T;
  end;

begin
  f := TCamSetForm.CreateNew(nil);
  try
    f.Caption := 'Pengaturan Kamera CCTV PH';
    f.BorderStyle := bsDialog;
    f.Position := poScreenCenter;
    f.ClientWidth := 900;
    f.ClientHeight := 430;
    f.Color := clrPanel;
    f.Font.Name := 'Segoe UI';
    f.Font.Color := clrText;
    MakeLabel(f, 'Aktif', 12, 10, clrMuted, 8, True);
    MakeLabel(f, 'Nama kamera / ruangan', 56, 10, clrMuted, 8, True);
    MakeLabel(f, 'Merek', 214, 10, clrMuted, 8, True);
    MakeLabel(f, 'Alamat RTSP (rtsp://IP:554/...)', 340, 10, clrMuted, 8, True);
    MakeLabel(f, 'User', 682, 10, clrMuted, 8, True);
    MakeLabel(f, 'Password', 786, 10, clrMuted, 8, True);
    for i := 0 to 3 do
    begin
      y := 32 + i * 34;
      f.cbOn[i] := TCheckBox.Create(f);
      f.cbOn[i].Parent := f;
      f.cbOn[i].SetBounds(18, y + 3, 20, 18);
      f.cbOn[i].Checked := Enabled_[i];
      f.edName[i] := Ed(f, 56, 150, Names[i]);
      f.cbBrand[i] := TComboBox.Create(f);
      f.cbBrand[i].Parent := f;
      f.cbBrand[i].Style := csDropDownList;
      f.cbBrand[i].SetBounds(214, y, 118, 22);
      f.cbBrand[i].Items.CommaText := '"Hikvision","Dahua / Imou","TP-Link Tapo","Ezviz","V380","Lainnya"';
      f.cbBrand[i].Tag := i;
      f.cbBrand[i].OnChange := f.BrandChange;
      f.edURL[i] := Ed(f, 340, 334, URLs[i]);
      f.edUser[i] := Ed(f, 682, 96, Users[i]);
      f.edPass[i] := Ed(f, 786, 100, Pass[i]);
      f.edPass[i].PasswordChar := '*';
    end;
    m := TMemo.Create(f);
    m.Parent := f;
    m.SetBounds(12, 172, 876, 196);
    m.ReadOnly := True;
    m.Color := clrPanel2;
    m.Font.Name := 'Consolas'; m.Font.Size := 8; m.Font.Color := clrText;
    m.Lines.Add('CONTOH ALAMAT RTSP (pilih Merek untuk isi otomatis, ganti 192.168.1.100 dengan IP kamera Anda):');
    m.Lines.Add('  Hikvision     rtsp://IP:554/Streaming/Channels/102        (101 = kualitas penuh, 102 = ringan)');
    m.Lines.Add('  Dahua / Imou  rtsp://IP:554/cam/realmonitor?channel=1&subtype=1   (subtype=0 = kualitas penuh)');
    m.Lines.Add('  TP-Link Tapo  rtsp://IP:554/stream2                       (buat "Camera Account" di aplikasi Tapo:');
    m.Lines.Add('                                                              Pengaturan > Advanced > Camera Account)');
    m.Lines.Add('  Ezviz         rtsp://IP:554/h264/ch1/sub/av_stream        (user admin, password = kode verifikasi');
    m.Lines.Add('                                                              di stiker bawah kamera)');
    m.Lines.Add('  V380          rtsp://IP:554/live/ch00_1');
    m.Lines.Add('');
    m.Lines.Add('TIPS: IP kamera bisa dilihat di aplikasi kamera / router. Kamera & komputer harus di jaringan WiFi yang sama.');
    m.Lines.Add('Pakai stream "ringan" (sub stream) agar 4 kamera lancar. Kamera H.265 butuh "HEVC Video Extensions"');
    m.Lines.Add('dari Microsoft Store; bila tidak, ubah encoding kamera ke H.264 di aplikasinya.');
    m.Lines.Add('Password disimpan di file cctv.ini di folder aplikasi (jangan dibagikan).');
    with TButton.Create(f) do
    begin
      Parent := f; Caption := 'SIMPAN && SAMBUNGKAN'; SetBounds(588, 384, 170, 32); ModalResult := mrOk; Default := True;
    end;
    with TButton.Create(f) do
    begin
      Parent := f; Caption := 'Batal'; SetBounds(766, 384, 122, 32); ModalResult := mrCancel; Cancel := True;
    end;
    Result := f.ShowModal = mrOk;
    if Result then
    begin
      for i := 0 to 3 do
      begin
        Names[i] := Trim(f.edName[i].Text);
        if Names[i] = '' then Names[i] := 'Kamera ' + IntToStr(i + 1);
        URLs[i] := Trim(f.edURL[i].Text);
        Users[i] := Trim(f.edUser[i].Text);
        Pass[i] := f.edPass[i].Text;
        Enabled_[i] := f.cbOn[i].Checked;
      end;
      SaveCfg;
    end;
  finally
    f.Free;
  end;
end;

procedure TCctvView.BtnSettings(Sender: TObject);
begin
  if ShowSettings and Visible then StartAll;
end;

end.
