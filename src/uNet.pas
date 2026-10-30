unit uNet;

{ HTTP GET via WinINet (mendukung TLS 1.2 bawaan Windows) + thread pengambil data }

interface

uses Windows, SysUtils, Classes, WinInet;

type
  TFetchThread = class;
  TFetchDone = procedure(T: TFetchThread) of object;

  TFetchThread = class(TThread)
  protected
    procedure Execute; override;
    procedure DoDone;
  public
    URLs: TStringList;      { tiap baris boleh berisi alternatif dipisah '|' }
    Results: TStringList;
    OKs: array of Boolean;
    UsedAlt: array of Integer;
    Kind, Seq: Integer;
    Info: string;
    OnDone: TFetchDone;
    constructor Create(AKind, ASeq: Integer; const AURLs: array of string; ADone: TFetchDone);
    destructor Destroy; override;
  end;

var
  AppClosing: Boolean = False;

function HttpGet(const URL: string; out Data: string): Boolean;

implementation

function HttpGet(const URL: string; out Data: string): Boolean;
var
  hNet, hUrl: HINTERNET;
  Buf: array[0..32767] of Char;
  n, code, len, idx, t: DWORD;
  ss: TStringStream;
begin
  Result := False;
  Data := '';
  hNet := InternetOpen('RecognitoTrading/1.0', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hNet = nil then Exit;
  try
    t := 12000;
    InternetSetOption(hNet, INTERNET_OPTION_CONNECT_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_RECEIVE_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_SEND_TIMEOUT, @t, SizeOf(t));
    hUrl := InternetOpenUrl(hNet, PChar(URL), nil, 0,
      INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_CACHE_WRITE or INTERNET_FLAG_PRAGMA_NOCACHE, 0);
    if hUrl = nil then Exit;
    try
      code := 0; len := SizeOf(code); idx := 0;
      HttpQueryInfo(hUrl, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER, @code, len, idx);
      ss := TStringStream.Create('');
      try
        repeat
          n := 0;
          if not InternetReadFile(hUrl, @Buf, SizeOf(Buf), n) then Break;
          if n > 0 then ss.WriteBuffer(Buf, n);
        until n = 0;
        Data := ss.DataString;
      finally
        ss.Free;
      end;
      Result := (code = 200) and (Length(Data) > 1);
    finally
      InternetCloseHandle(hUrl);
    end;
  finally
    InternetCloseHandle(hNet);
  end;
end;

constructor TFetchThread.Create(AKind, ASeq: Integer; const AURLs: array of string; ADone: TFetchDone);
var i: Integer;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  Kind := AKind;
  Seq := ASeq;
  OnDone := ADone;
  URLs := TStringList.Create;
  Results := TStringList.Create;
  for i := 0 to High(AURLs) do URLs.Add(AURLs[i]);
  Resume;
end;

destructor TFetchThread.Destroy;
begin
  URLs.Free;
  Results.Free;
  inherited;
end;

procedure TFetchThread.Execute;
var i, a: Integer; alts: TStringList; s: string; ok: Boolean;
begin
  SetLength(OKs, URLs.Count);
  SetLength(UsedAlt, URLs.Count);
  alts := TStringList.Create;
  try
    for i := 0 to URLs.Count - 1 do
    begin
      alts.Clear;
      alts.Text := StringReplace(URLs[i], '|', #13#10, [rfReplaceAll]);
      ok := False; s := '';
      UsedAlt[i] := -1;
      for a := 0 to alts.Count - 1 do
      begin
        if Terminated or AppClosing then Exit;
        if HttpGet(alts[a], s) and (s[1] in ['[', '{']) then
        begin
          ok := True;
          UsedAlt[i] := a;
          Break;
        end;
      end;
      OKs[i] := ok;
      if ok then Results.Add(s) else Results.Add('');
    end;
  finally
    alts.Free;
  end;
  if not AppClosing then Synchronize(DoDone);
end;

procedure TFetchThread.DoDone;
begin
  if (not AppClosing) and Assigned(OnDone) then OnDone(Self);
end;

end.
