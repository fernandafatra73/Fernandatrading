unit uMT5;

{ Jembatan ke MetaTrader 5 lewat folder Common\Files MT5:
  aplikasi menulis RecognitoCmd.txt, EA RecognitoBridge menulis RecognitoStatus.txt }

interface

uses Windows, SysUtils, Classes;

function MT5CommonDir: string;
function MT5WriteCmd(AutoOn, CloseAll: Boolean; LotBuy, LotSell: Double): Boolean;
function MT5ReadStatus(SL: TStringList; out AgeSec: Double): Boolean;
function MT5WriteOrder(const Sym, Side, OType: string; Lot, Price: Double; out ID: string): Boolean;
function MT5ExtractEA(const FileName: string): Boolean;
function MT5InstallEA(Dirs: TStrings): Integer;

implementation

var
  CmdSeq: Integer = 0;

function EnvVar(const Name: string): string;
var Buf: array[0..1023] of Char;
begin
  if GetEnvironmentVariable(PChar(Name), Buf, SizeOf(Buf)) > 0 then Result := Buf else Result := '';
end;

function TerminalRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(EnvVar('APPDATA')) + 'MetaQuotes\Terminal\';
end;

function MT5CommonDir: string;
begin
  Result := TerminalRoot + 'Common\Files\';
end;

function MT5WriteCmd(AutoOn, CloseAll: Boolean; LotBuy, LotSell: Double): Boolean;
var sl: TStringList;
begin
  Result := False;
  Inc(CmdSeq);
  sl := TStringList.Create;
  try
    sl.Add('ID=' + FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' + IntToStr(CmdSeq));
    { aplikasi tidak bisa mengaktifkan order robot (hanya pengguna di chart MT5),
      hanya bisa menghentikannya: AutoOn = False -> STOP=1 }
    if AutoOn then sl.Add('STOP=0') else sl.Add('STOP=1');
    if CloseAll then sl.Add('CLOSEALL=1') else sl.Add('CLOSEALL=0');
    sl.Add('LOTBUY=' + FormatFloat('0.00', LotBuy));
    sl.Add('LOTSELL=' + FormatFloat('0.00', LotSell));
    sl.Add('APP=Fernanda Trading Recognito');
    try
      ForceDirectories(MT5CommonDir);
      sl.SaveToFile(MT5CommonDir + 'RecognitoCmd.txt');
      Result := True;
    except
      Result := False;
    end;
  finally
    sl.Free;
  end;
end;

{ order manual pengguna (BUY / SELL, MARKET / PENDING) ke RecognitoOrder.txt;
  EA mengeksekusi sekali dan mengabaikan order yang lebih tua dari 20 detik.
  Sym = simbol MT5 (mis. XAUUSDm, BTCUSDm); kosong = simbol chart tempat EA dipasang }
function MT5WriteOrder(const Sym, Side, OType: string; Lot, Price: Double; out ID: string): Boolean;
var sl: TStringList;
begin
  Result := False;
  Inc(CmdSeq);
  ID := FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' + IntToStr(CmdSeq);
  sl := TStringList.Create;
  try
    sl.Add('ID=' + ID);
    sl.Add('SIDE=' + Side);
    sl.Add('TYPE=' + OType);
    sl.Add('SYMBOL=' + Sym);
    sl.Add('LOT=' + FormatFloat('0.00', Lot));
    sl.Add('PRICE=' + FormatFloat('0.00######', Price));
    sl.Add('TIME=' + FormatDateTime('yyyy.mm.dd hh:nn:ss', Now));
    try
      ForceDirectories(MT5CommonDir);
      sl.SaveToFile(MT5CommonDir + 'RecognitoOrder.txt');
      Result := True;
    except
      Result := False;
    end;
  finally
    sl.Free;
  end;
end;

function MT5ReadStatus(SL: TStringList; out AgeSec: Double): Boolean;
var fn: string; fs: TFileStream; age: Integer;
begin
  Result := False;
  AgeSec := 1E9;
  SL.Clear;
  fn := MT5CommonDir + 'RecognitoStatus.txt';
  if not FileExists(fn) then Exit;
  try
    fs := TFileStream.Create(fn, fmOpenRead or fmShareDenyNone);
    try
      SL.LoadFromStream(fs);
    finally
      fs.Free;
    end;
    age := FileAge(fn);
    if age <> -1 then AgeSec := (Now - FileDateToDateTime(age)) * 86400;
    Result := SL.Count > 0;
  except
    Result := False;
  end;
end;

function MT5ExtractEA(const FileName: string): Boolean;
var rs: TResourceStream;
begin
  Result := False;
  try
    rs := TResourceStream.Create(HInstance, 'EA_MQ5', RT_RCDATA);
    try
      ForceDirectories(ExtractFilePath(FileName));
      rs.SaveToFile(FileName);
      Result := True;
    finally
      rs.Free;
    end;
  except
    Result := False;
  end;
end;

function MT5InstallEA(Dirs: TStrings): Integer;
var sr: TSearchRec; d: string;
begin
  Result := 0;
  if FindFirst(TerminalRoot + '*', faDirectory, sr) = 0 then
  try
    repeat
      if (sr.Attr and faDirectory = 0) or (sr.Name = '.') or (sr.Name = '..') then Continue;
      d := TerminalRoot + sr.Name + '\MQL5\Experts\';
      if DirectoryExists(d) and MT5ExtractEA(d + 'RecognitoBridge.mq5') then
      begin
        Inc(Result);
        if Dirs <> nil then Dirs.Add(d);
      end;
    until FindNext(sr) <> 0;
  finally
    FindClose(sr);
  end;
end;

end.
