unit uRec;

{ Perekam layar ke MP4 (H.264) memakai Media Foundation bawaan Windows 7/8/10/11.
  - berjalan di thread sendiri (tidak membebani grafik)
  - file dipecah per segmen (default 15 menit) agar aman bila komputer mati mendadak
  - batas ukuran folder: video terlama dihapus otomatis bila melebihi batas / disk hampir penuh }

interface

uses Windows, SysUtils, Classes, Math, uMF;

type
  TScreenRecorder = class(TThread)
  private
    FCS: TRTLCriticalSection;
    FDir: string;
    FStatus, FCurFile, FError: string;
    FRecording: Boolean;
    FSegStart: TDateTime;
    FW, FH: Integer;
    FTotalBytes: Int64;
    procedure SetInfo(const Status, Cur, Err: string; Rec: Boolean);
    procedure Enforce(const KeepFile: string);
  protected
    procedure Execute; override;
  public
    Enabled: Boolean;       { False = jeda (segmen aktif ditutup) }
    Fps: Integer;
    MaxWidth: Integer;
    SegMinutes: Integer;
    MaxBytes: Int64;        { batas total folder video }
    MinFreeBytes: Int64;    { sisa disk minimal }
    constructor Create(const ADir: string);
    destructor Destroy; override;
    procedure GetInfo(out Status, Cur, Err: string; out Rec: Boolean; out SegStart: TDateTime;
      out W, H: Integer; out Total: Int64);
  end;

function FolderBytes(const Dir, Mask: string): Int64;

implementation


function FolderBytes(const Dir, Mask: string): Int64;
var sr: TSearchRec;
begin
  Result := 0;
  if FindFirst(Dir + Mask, faAnyFile, sr) = 0 then
  begin
    repeat
      if (sr.Attr and faDirectory) = 0 then
        Result := Result + (Int64(sr.FindData.nFileSizeHigh) shl 32) + sr.FindData.nFileSizeLow;
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
end;

function DiskFree(const Dir: string): Int64;
var avail, total, free: Int64;
begin
  if GetDiskFreeSpaceEx(PChar(ExtractFileDrive(Dir) + '\'), avail, total, @free) then Result := avail
  else Result := High(Int64);
end;

{ ---------------- TScreenRecorder ---------------- }

constructor TScreenRecorder.Create(const ADir: string);
begin
  inherited Create(True);
  InitializeCriticalSection(FCS);
  FDir := IncludeTrailingPathDelimiter(ADir);
  Enabled := True;
  Fps := 5;
  MaxWidth := 1280;
  SegMinutes := 15;
  MaxBytes := Int64(3) * 1024 * 1024 * 1024;
  MinFreeBytes := Int64(1024) * 1024 * 1024;
  FStatus := 'Menyiapkan perekam...';
  FreeOnTerminate := False;
end;

destructor TScreenRecorder.Destroy;
begin
  DeleteCriticalSection(FCS);
  inherited;
end;

procedure TScreenRecorder.SetInfo(const Status, Cur, Err: string; Rec: Boolean);
begin
  EnterCriticalSection(FCS);
  try
    FStatus := Status;
    FCurFile := Cur;
    if Err <> '' then FError := Err;
    FRecording := Rec;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

procedure TScreenRecorder.GetInfo(out Status, Cur, Err: string; out Rec: Boolean; out SegStart: TDateTime;
  out W, H: Integer; out Total: Int64);
begin
  EnterCriticalSection(FCS);
  try
    Status := FStatus;
    Cur := FCurFile;
    Err := FError;
    Rec := FRecording;
    SegStart := FSegStart;
    W := FW; H := FH;
    Total := FTotalBytes;
  finally
    LeaveCriticalSection(FCS);
  end;
end;

{ hapus video terlama bila folder melebihi batas atau disk hampir penuh }
procedure TScreenRecorder.Enforce(const KeepFile: string);
var sl: TStringList; sr: TSearchRec; total: Int64; i: Integer;
begin
  sl := TStringList.Create;
  try
    total := 0;
    if FindFirst(FDir + 'Rekam_*.mp4', faAnyFile, sr) = 0 then
    begin
      repeat
        if (sr.Attr and faDirectory) = 0 then
        begin
          sl.AddObject(sr.Name, TObject(Integer(sr.FindData.nFileSizeLow)));
          total := total + (Int64(sr.FindData.nFileSizeHigh) shl 32) + sr.FindData.nFileSizeLow;
        end;
      until FindNext(sr) <> 0;
      FindClose(sr);
    end;
    sl.Sort; { nama berisi tanggal: urut = terlama dulu }
    i := 0;
    while (i < sl.Count) and ((total > MaxBytes) or (DiskFree(FDir) < MinFreeBytes)) do
    begin
      if not SameText(sl[i], ExtractFileName(KeepFile)) then
        if DeleteFile(FDir + sl[i]) then total := total - Int64(Cardinal(Integer(sl.Objects[i])));
      Inc(i);
    end;
    EnterCriticalSection(FCS);
    FTotalBytes := total;
    LeaveCriticalSection(FCS);
  finally
    sl.Free;
  end;
end;

procedure TScreenRecorder.Execute;
var
  writer: IMFSinkWriter;
  outT, inT: IMFMediaType;
  enc: IMFAttributes;
  sample: IMFSample;
  buf: IMFMediaBuffer;
  stream: DWORD;
  pData: Pointer;
  scrDC, memDC: HDC;
  bmp, oldBmp: HBITMAP;
  bi: TBitmapInfo;
  bits: Pointer;
  sx, sy, sw, sh, tw, th, frameBytes: Integer;
  freq, t0, tNow, tPrev: Int64;
  frameDur, ts: Int64;
  segEnd: TDateTime;
  fn: string;
  ci: TCursorInfo; ii: TIconInfo;
  cx, cy: Integer;
  waitMs: Integer;
  hr: HResult;

  procedure CloseSeg;
  begin
    if writer <> nil then
    begin
      writer.Finalize;
      writer := nil;
    end;
    if memDC <> 0 then
    begin
      SelectObject(memDC, oldBmp);
      DeleteObject(bmp);
      DeleteDC(memDC);
      memDC := 0;
    end;
  end;

  function OpenSeg: Boolean;
  begin
    Result := False;
    sx := GetSystemMetrics(SM_XVIRTUALSCREEN);
    sy := GetSystemMetrics(SM_YVIRTUALSCREEN);
    sw := GetSystemMetrics(SM_CXVIRTUALSCREEN);
    sh := GetSystemMetrics(SM_CYVIRTUALSCREEN);
    if (sw < 64) or (sh < 64) then Exit;
    tw := Min(sw, MaxWidth);
    th := Round(sh * tw / sw);
    tw := (tw div 16) * 16;
    th := (th div 16) * 16;
    frameBytes := tw * th * 4;

    ForceDirectories(FDir);
    Enforce('');
    if DiskFree(FDir) < MinFreeBytes then
    begin
      SetInfo('Disk hampir penuh - rekaman dijeda', '', 'Sisa disk kurang dari batas minimal.', False);
      Exit;
    end;

    { DIB 32-bit top-down sebagai bingkai }
    FillChar(bi, SizeOf(bi), 0);
    bi.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    bi.bmiHeader.biWidth := tw;
    bi.bmiHeader.biHeight := -th;
    bi.bmiHeader.biPlanes := 1;
    bi.bmiHeader.biBitCount := 32;
    bi.bmiHeader.biCompression := BI_RGB;
    scrDC := GetDC(0);
    memDC := CreateCompatibleDC(scrDC);
    ReleaseDC(0, scrDC);
    bmp := CreateDIBSection(memDC, bi, DIB_RGB_COLORS, bits, 0, 0);
    if bmp = 0 then begin DeleteDC(memDC); memDC := 0; Exit; end;
    oldBmp := SelectObject(memDC, bmp);
    SetStretchBltMode(memDC, HALFTONE);
    SetBrushOrgEx(memDC, 0, 0, nil);

    fn := FDir + 'Rekam_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.mp4';
    hr := MFCreateSinkWriterFromURL(PWideChar(WideString(fn)), nil, nil, writer);
    if Failed(hr) then begin SetInfo('Gagal membuat file video', '', Format('MFCreateSinkWriterFromURL 0x%.8x', [hr]), False); CloseSeg; Exit; end;

    MFCreateMediaType(outT);
    outT.SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    outT.SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
    outT.SetUINT32(MF_MT_AVG_BITRATE, 900000);
    outT.SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
    outT.SetUINT64(MF_MT_FRAME_SIZE, Pack64(tw, th));
    outT.SetUINT64(MF_MT_FRAME_RATE, Pack64(Fps, 1));
    outT.SetUINT64(MF_MT_PIXEL_ASPECT_RATIO, Pack64(1, 1));
    hr := writer.AddStream(outT, stream);
    if Failed(hr) then begin SetInfo('Encoder H.264 tidak tersedia', '', Format('AddStream 0x%.8x', [hr]), False); writer := nil; CloseSeg; DeleteFile(fn); Exit; end;

    MFCreateMediaType(inT);
    inT.SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    inT.SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);
    inT.SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
    inT.SetUINT64(MF_MT_FRAME_SIZE, Pack64(tw, th));
    inT.SetUINT64(MF_MT_FRAME_RATE, Pack64(Fps, 1));
    inT.SetUINT64(MF_MT_PIXEL_ASPECT_RATIO, Pack64(1, 1));
    inT.SetUINT32(MF_MT_DEFAULT_STRIDE, DWORD(tw * 4));
    { mode kualitas: layar diam = file kecil }
    MFCreateAttributes(enc, 2);
    enc.SetUINT32(CODECAPI_AVEncCommonRateControlMode, RateControl_Quality);
    enc.SetUINT32(CODECAPI_AVEncCommonQuality, 60);
    hr := writer.SetInputMediaType(stream, inT, enc);
    if Failed(hr) then hr := writer.SetInputMediaType(stream, inT, nil);
    if Succeeded(hr) then hr := writer.BeginWriting;
    if Failed(hr) then begin SetInfo('Gagal memulai encoder video', '', Format('SetInputMediaType 0x%.8x', [hr]), False); writer := nil; CloseSeg; DeleteFile(fn); Exit; end;

    QueryPerformanceCounter(t0);
    tPrev := -1;
    frameDur := 10000000 div Fps;
    segEnd := Now + SegMinutes / 1440;
    EnterCriticalSection(FCS);
    FSegStart := Now; FW := tw; FH := th;
    LeaveCriticalSection(FCS);
    SetInfo('Merekam', fn, '', True);
    Result := True;
  end;

begin
  writer := nil; memDC := 0;
  if not MFAvailable then
  begin
    SetInfo('Media Foundation tidak ada di Windows ini (edisi N?) - video tidak bisa direkam', '', 'mfplat.dll tidak ditemukan', False);
    Exit;
  end;
  CoInitializeEx_(nil, COINIT_MULTITHREADED_);
  try
    if Failed(MFStartup(MF_VERSION, MFSTARTUP_FULL)) then
    begin
      SetInfo('Media Foundation gagal dijalankan', '', 'MFStartup gagal', False);
      Exit;
    end;
    try
      QueryPerformanceFrequency(freq);
      while not Terminated do
      begin
        if not Enabled then
        begin
          if writer <> nil then begin CloseSeg; Enforce(''); end;
          SetInfo('Rekaman video MATI', '', '', False);
          Sleep(250);
          Continue;
        end;
        if writer = nil then
          if not OpenSeg then
          begin
            { coba lagi 30 detik lagi }
            for waitMs := 1 to 120 do if Terminated or not Enabled then Break else Sleep(250);
            Continue;
          end;

        { ambil layar + kursor mouse }
        scrDC := GetDC(0);
        if StretchBlt(memDC, 0, 0, tw, th, scrDC, sx, sy, sw, sh, SRCCOPY) then
        begin
          ci.cbSize := SizeOf(ci);
          if GetCursorInfo(ci) and (ci.flags = CURSOR_SHOWING) and GetIconInfo(ci.hCursor, ii) then
          begin
            cx := MulDiv(ci.ptScreenPos.X - sx, tw, sw) - Integer(ii.xHotspot);
            cy := MulDiv(ci.ptScreenPos.Y - sy, th, sh) - Integer(ii.yHotspot);
            DrawIconEx(memDC, cx, cy, ci.hCursor, 0, 0, 0, 0, DI_NORMAL);
            if ii.hbmMask <> 0 then DeleteObject(ii.hbmMask);
            if ii.hbmColor <> 0 then DeleteObject(ii.hbmColor);
          end;
          GdiFlush;
          QueryPerformanceCounter(tNow);
          ts := Round((tNow - t0) / freq * 10000000);
          if ts <= tPrev then ts := tPrev + 1;
          tPrev := ts;
          buf := nil; sample := nil;
          if Succeeded(MFCreateMemoryBuffer(frameBytes, buf)) and Succeeded(buf.Lock(pData, nil, nil)) then
          begin
            Move(bits^, pData^, frameBytes);
            buf.Unlock;
            buf.SetCurrentLength(frameBytes);
            if Succeeded(MFCreateSample(sample)) then
            begin
              sample.AddBuffer(buf);
              sample.SetSampleTime(ts);
              sample.SetSampleDuration(frameDur);
              hr := writer.WriteSample(stream, sample);
              if Failed(hr) then
              begin
                SetInfo('Gagal menulis video', '', Format('WriteSample 0x%.8x', [hr]), False);
                CloseSeg;
              end;
            end;
          end;
          sample := nil; buf := nil;
        end;
        ReleaseDC(0, scrDC);

        { segmen baru bila waktunya habis atau resolusi layar berubah }
        if (writer <> nil) and ((Now >= segEnd) or (GetSystemMetrics(SM_CXVIRTUALSCREEN) <> sw) or
           (GetSystemMetrics(SM_CYVIRTUALSCREEN) <> sh)) then
          CloseSeg;

        { tunggu bingkai berikutnya }
        QueryPerformanceCounter(tNow);
        waitMs := 1000 div Fps - Round((tNow - t0) / freq * 1000 - tPrev / 10000);
        if waitMs > 1000 div Fps then waitMs := 1000 div Fps;
        if waitMs > 0 then Sleep(waitMs);
      end;
    finally
      CloseSeg;
      Enforce('');
      SetInfo('Rekaman berhenti', '', '', False);
      MFShutdown;
    end;
  finally
    CoUninitialize_;
  end;
end;

end.
