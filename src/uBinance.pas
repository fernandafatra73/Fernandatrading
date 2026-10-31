unit uBinance;

{ Order Binance Spot atas perintah pengguna (tombol OPEN BINANCE):
  - API key / secret disimpan di binance.ini di folder aplikasi (jangan dibagikan)
  - request bertanda tangan HMAC-SHA256 ke api.binance.com lewat WinINet
  - MARKET memakai quoteOrderQty (jumlah USDT), LIMIT dibulatkan ke stepSize / tickSize simbol }

interface

uses Windows, SysUtils, Classes, WinInet, Math;

function SHA256Hex(const S: string): string;
function HmacSHA256Hex(const Key, Msg: string): string;

procedure BinLoadKeys(const FileName: string);
procedure BinSaveKeys(const FileName, AKey, ASecret: string);
function BinHasKeys: Boolean;
function BinKeyMasked: string;

{ saldo bebas USDT & koin (Base, mis. 'ETH') }
function BinBalances(const Base: string; out FreeUSDT, FreeBase: Double; out Msg: string): Boolean;
{ Side 'BUY' / 'SELL', OType 'MARKET' / 'LIMIT'; Usdt = nilai order dalam USDT }
function BinOrder(const Sym, Side, OType: string; Usdt, LimitPrice: Double; out Msg: string): Boolean;

implementation

{$Q-}{$R-}

var
  ApiKey, ApiSecret: string;

{ ---------------- SHA-256 / HMAC ---------------- }

const
  K256: array[0..63] of Cardinal = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2);

function ROR(x: Cardinal; n: Integer): Cardinal;
begin
  Result := (x shr n) or (x shl (32 - n));
end;

{ hasil 32 byte mentah }
function SHA256Raw(const S: string): string;
var
  h: array[0..7] of Cardinal;
  w: array[0..63] of Cardinal;
  msg: string;
  i, j, blk: Integer;
  a, b, c, d, e, f, g, hh, s0, s1, t1, t2: Cardinal;
  bits: Int64;
begin
  h[0] := $6a09e667; h[1] := $bb67ae85; h[2] := $3c6ef372; h[3] := $a54ff53a;
  h[4] := $510e527f; h[5] := $9b05688c; h[6] := $1f83d9ab; h[7] := $5be0cd19;
  bits := Int64(Length(S)) * 8;
  msg := S + #$80;
  while (Length(msg) mod 64) <> 56 do msg := msg + #0;
  for i := 7 downto 0 do msg := msg + Chr((bits shr (i * 8)) and $FF);
  for blk := 0 to Length(msg) div 64 - 1 do
  begin
    for i := 0 to 15 do
    begin
      j := blk * 64 + i * 4 + 1;
      w[i] := (Cardinal(Ord(msg[j])) shl 24) or (Cardinal(Ord(msg[j + 1])) shl 16) or
              (Cardinal(Ord(msg[j + 2])) shl 8) or Cardinal(Ord(msg[j + 3]));
    end;
    for i := 16 to 63 do
    begin
      s0 := ROR(w[i - 15], 7) xor ROR(w[i - 15], 18) xor (w[i - 15] shr 3);
      s1 := ROR(w[i - 2], 17) xor ROR(w[i - 2], 19) xor (w[i - 2] shr 10);
      w[i] := w[i - 16] + s0 + w[i - 7] + s1;
    end;
    a := h[0]; b := h[1]; c := h[2]; d := h[3]; e := h[4]; f := h[5]; g := h[6]; hh := h[7];
    for i := 0 to 63 do
    begin
      s1 := ROR(e, 6) xor ROR(e, 11) xor ROR(e, 25);
      t1 := hh + s1 + ((e and f) xor ((not e) and g)) + K256[i] + w[i];
      s0 := ROR(a, 2) xor ROR(a, 13) xor ROR(a, 22);
      t2 := s0 + ((a and b) xor (a and c) xor (b and c));
      hh := g; g := f; f := e; e := d + t1;
      d := c; c := b; b := a; a := t1 + t2;
    end;
    Inc(h[0], a); Inc(h[1], b); Inc(h[2], c); Inc(h[3], d);
    Inc(h[4], e); Inc(h[5], f); Inc(h[6], g); Inc(h[7], hh);
  end;
  Result := '';
  for i := 0 to 7 do
    Result := Result + Chr(h[i] shr 24) + Chr((h[i] shr 16) and $FF) + Chr((h[i] shr 8) and $FF) + Chr(h[i] and $FF);
end;

function ToHex(const S: string): string;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do Result := Result + LowerCase(IntToHex(Ord(S[i]), 2));
end;

function SHA256Hex(const S: string): string;
begin
  Result := ToHex(SHA256Raw(S));
end;

function HmacSHA256Hex(const Key, Msg: string): string;
var k, ipad, opad: string; i: Integer;
begin
  k := Key;
  if Length(k) > 64 then k := SHA256Raw(k);
  while Length(k) < 64 do k := k + #0;
  SetLength(ipad, 64); SetLength(opad, 64);
  for i := 1 to 64 do
  begin
    ipad[i] := Chr(Ord(k[i]) xor $36);
    opad[i] := Chr(Ord(k[i]) xor $5C);
  end;
  Result := ToHex(SHA256Raw(opad + SHA256Raw(ipad + Msg)));
end;

{ ---------------- kunci API ---------------- }

procedure BinLoadKeys(const FileName: string);
begin
  ApiKey := ''; ApiSecret := '';
  if not FileExists(FileName) then Exit;
  with TStringList.Create do
  try
    LoadFromFile(FileName);
    ApiKey := Trim(Values['KEY']);
    ApiSecret := Trim(Values['SECRET']);
  finally
    Free;
  end;
end;

procedure BinSaveKeys(const FileName, AKey, ASecret: string);
begin
  ApiKey := Trim(AKey); ApiSecret := Trim(ASecret);
  with TStringList.Create do
  try
    Values['KEY'] := ApiKey;
    Values['SECRET'] := ApiSecret;
    SaveToFile(FileName);
  finally
    Free;
  end;
end;

function BinHasKeys: Boolean;
begin
  Result := (ApiKey <> '') and (ApiSecret <> '');
end;

function BinKeyMasked: string;
begin
  if ApiKey = '' then Result := '(belum diisi)'
  else Result := Copy(ApiKey, 1, 4) + '...' + Copy(ApiKey, Length(ApiKey) - 3, 4);
end;

{ ---------------- HTTP ke api.binance.com ---------------- }

function BinHttp(const Method, Path, Query: string; out Data: string; out Code: Integer): Boolean;
var
  hNet, hCon, hReq: HINTERNET;
  Buf: array[0..16383] of Char;
  n, c, len, idx, t: DWORD;
  hdr, url, part: string;
begin
  Result := False; Data := ''; Code := 0;
  hNet := InternetOpen('RecognitoTrading/1.0', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if hNet = nil then Exit;
  try
    t := 15000;
    InternetSetOption(hNet, INTERNET_OPTION_CONNECT_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_RECEIVE_TIMEOUT, @t, SizeOf(t));
    InternetSetOption(hNet, INTERNET_OPTION_SEND_TIMEOUT, @t, SizeOf(t));
    hCon := InternetConnect(hNet, 'api.binance.com', INTERNET_DEFAULT_HTTPS_PORT, nil, nil, INTERNET_SERVICE_HTTP, 0, 0);
    if hCon = nil then Exit;
    try
      url := Path;
      if Query <> '' then url := url + '?' + Query;
      hReq := HttpOpenRequest(hCon, PChar(Method), PChar(url), nil, nil, nil,
        INTERNET_FLAG_SECURE or INTERNET_FLAG_RELOAD or INTERNET_FLAG_NO_CACHE_WRITE, 0);
      if hReq = nil then Exit;
      try
        hdr := '';
        if ApiKey <> '' then hdr := 'X-MBX-APIKEY: ' + ApiKey + #13#10;
        if not HttpSendRequest(hReq, PChar(hdr), Length(hdr), nil, 0) then Exit;
        c := 0; len := SizeOf(c); idx := 0;
        HttpQueryInfo(hReq, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER, @c, len, idx);
        Code := c;
        repeat
          n := 0;
          if not InternetReadFile(hReq, @Buf, SizeOf(Buf), n) then Break;
          if n > 0 then
          begin
            SetString(part, Buf, n);
            Data := Data + part;
          end;
        until n = 0;
        Result := Code = 200;
      finally
        InternetCloseHandle(hReq);
      end;
    finally
      InternetCloseHandle(hCon);
    end;
  finally
    InternetCloseHandle(hNet);
  end;
end;

{ nilai sederhana dari JSON: "name":"value" atau "name":123 }
function JStr(const J, Name: string; From: Integer = 1): string;
var p, q: Integer; s: string;
begin
  Result := '';
  s := Copy(J, From, MaxInt);
  p := Pos('"' + Name + '":', s);
  if p = 0 then Exit;
  Inc(p, Length(Name) + 3);
  if (p <= Length(s)) and (s[p] = '"') then
  begin
    q := p + 1;
    while (q <= Length(s)) and (s[q] <> '"') do Inc(q);
    Result := Copy(s, p + 1, q - p - 1);
  end
  else
  begin
    q := p;
    while (q <= Length(s)) and not (s[q] in [',', '}', ']']) do Inc(q);
    Result := Trim(Copy(s, p, q - p));
  end;
end;

function PF(const S: string): Double;
begin
  Result := StrToFloatDef(StringReplace(S, ',', '.', []), 0);
end;

// pesan error Binance: "code":-2010,"msg":"..."
function ErrMsg(const Data: string; Code: Integer): string;
begin
  Result := JStr(Data, 'msg');
  if Result = '' then
    if Code = 0 then Result := 'tidak bisa terhubung ke api.binance.com'
    else Result := 'HTTP ' + IntToStr(Code);
end;

function GetTimeZoneBiasMin: Integer;
var tz: TTimeZoneInformation; r: DWORD;
begin
  r := GetTimeZoneInformation(tz);
  Result := -tz.Bias;
  if r = TIME_ZONE_ID_DAYLIGHT then Result := Result - tz.DaylightBias;
end;

function NowMsUTC: Int64;
begin
  Result := Round((Now - EncodeDate(1970, 1, 1)) * 86400000) - Round(GetTimeZoneBiasMin * 60000);
end;

{ selisih jam komputer vs server Binance (ms), supaya timestamp tidak ditolak }
function ServerOffsetMs: Int64;
var d: string; c: Integer; st: Int64;
begin
  Result := 0;
  if not BinHttp('GET', '/api/v3/time', '', d, c) then Exit;
  st := StrToInt64Def(JStr(d, 'serverTime'), 0);
  if st > 0 then Result := st - NowMsUTC;
end;

function Signed(const Method, Path, Params: string; out Data: string; out Code: Integer): Boolean;
var q: string;
begin
  q := Params;
  if q <> '' then q := q + '&';
  q := q + 'recvWindow=10000&timestamp=' + IntToStr(NowMsUTC + ServerOffsetMs);
  q := q + '&signature=' + HmacSHA256Hex(ApiSecret, q);
  Result := BinHttp(Method, Path, q, Data, Code);
end;

function BinBalances(const Base: string; out FreeUSDT, FreeBase: Double; out Msg: string): Boolean;
var d: string; c, p: Integer;
begin
  FreeUSDT := 0; FreeBase := 0;
  Result := False;
  if not BinHasKeys then begin Msg := 'API key Binance belum diisi'; Exit; end;
  if not Signed('GET', '/api/v3/account', 'omitZeroBalances=true', d, c) then
  begin
    Msg := ErrMsg(d, c);
    Exit;
  end;
  p := Pos('"asset":"USDT"', d);
  if p > 0 then FreeUSDT := PF(JStr(d, 'free', p));
  if Base <> '' then
  begin
    p := Pos('"asset":"' + Base + '"', d);
    if p > 0 then FreeBase := PF(JStr(d, 'free', p));
  end;
  Msg := '';
  Result := True;
end;

{ stepSize (LOT_SIZE) & tickSize (PRICE_FILTER) simbol }
function Filters(const Sym: string; out Step, Tick: Double): Boolean;
var d: string; c, p: Integer;
begin
  Step := 0; Tick := 0;
  Result := BinHttp('GET', '/api/v3/exchangeInfo', 'symbol=' + Sym, d, c);
  if not Result then Exit;
  p := Pos('"filterType":"PRICE_FILTER"', d);
  if p > 0 then Tick := PF(JStr(d, 'tickSize', p));
  p := Pos('"filterType":"LOT_SIZE"', d);
  if p > 0 then Step := PF(JStr(d, 'stepSize', p));
  Result := (Step > 0) and (Tick > 0);
end;

function Decs(Step: Double): Integer;
begin
  Result := 0;
  while (Result < 10) and (Abs(Step * Power(10, Result) - Round(Step * Power(10, Result))) > 1E-9) do Inc(Result);
end;

function Fix(V: Double; Dec: Integer): string;
begin
  Result := FormatFloat('0.' + StringOfChar('0', Max(Dec, 1)), V);
  if Dec = 0 then Result := FormatFloat('0', V);
end;

function BinOrder(const Sym, Side, OType: string; Usdt, LimitPrice: Double; out Msg: string): Boolean;
var d, q: string; c: Integer; step, tick, qty, px: Double;
begin
  Result := False;
  if not BinHasKeys then begin Msg := 'API key Binance belum diisi'; Exit; end;
  if OType = 'LIMIT' then
  begin
    if not Filters(Sym, step, tick) then
    begin
      Msg := 'gagal membaca aturan simbol ' + Sym;
      Exit;
    end;
    px := Round(LimitPrice / tick) * tick;
    qty := Floor(Usdt / px / step + 1E-9) * step;
    if qty <= 0 then
    begin
      Msg := 'jumlah terlalu kecil untuk harga ini';
      Exit;
    end;
    q := Format('symbol=%s&side=%s&type=LIMIT&timeInForce=GTC&quantity=%s&price=%s',
      [Sym, Side, Fix(qty, Decs(step)), Fix(px, Decs(tick))]);
  end
  else
    q := Format('symbol=%s&side=%s&type=MARKET&quoteOrderQty=%s', [Sym, Side, Fix(Usdt, 2)]);
  if not Signed('POST', '/api/v3/order', q, d, c) then
  begin
    Msg := ErrMsg(d, c);
    Exit;
  end;
  Msg := Format('%s %s %s  status %s  (qty %s, order #%s)',
    [Side, OType, Sym, JStr(d, 'status'), JStr(d, 'executedQty'), JStr(d, 'orderId')]);
  if OType = 'LIMIT' then Msg := Msg + '  @ ' + JStr(d, 'price');
  Result := True;
end;

end.
