unit uMain;

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ExtCtrls, StdCtrls,
  ComCtrls, Grids, Math, DateUtils, StrUtils, ShellAPI,
  Dialogs, Jpeg, Registry, Menus, uUI, uNet, uData, uChart, uSession, uMT5, uRec, uCctv;

const
  TFNames: array[0..7] of string = ('1m', '5m', '15m', '30m', '1h', '4h', '1d', '1w');
  TFLabels: array[0..7] of string = ('1m', '5m', '15m', '30m', '1H', '4H', '1D', '1W');
  TFSecs: array[0..7] of Integer = (60, 300, 900, 1800, 3600, 14400, 86400, 604800);
  SessColors: array[0..3] of TColor = ($B0279C, $631EE9, $FF7929, $81CB0E);

  LinkURLs: array[0..2] of string = (
    'https://my.extrade.global/accounts/sign-in?redirect=%2Fwebtrading%2F%3Futm_source%3Dmc%26utm_medium%3Demail%26partner_id%3D12058011%26utm_campaign%3DWeekly_Recap_USOIL_ACT_Chart_20261028',
    'https://www.binance.bh/en/futures/PAXGUSDT',
    'https://www.tradewill-global.com/');

  KIND_MAIN = 1; KIND_LIVE = 2; KIND_MTF = 3; KIND_TICK = 4; KIND_CAL = 5; KIND_PROBE = 6;

type
  TBeepThread = class(TThread)
  private
    FKind: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AKind: Integer);
  end;

  TMainForm = class(TForm)
  private
    pnlTop, pnlTopR, pnlInd, pnlStatus, pnlLeft, pnlRight, pnlCenter, pnlToast, pnlGold: TPanel;
    lblSym, lblPrice, lblChg, lblClock, lblSess, lblSessNext, lblSignal, lblStatus,
    lblToast, lblGoldPrice, lblGoldChg, lblGoldSrc, lblCount: TLabel;
    btnGold, btnAlarm, btnLeft, btnRight: TFlatBtn;
    btnTF: array[0..7] of TFlatBtn;
    btnInd: array[0..11] of TFlatBtn;
    btnCat: array[0..5] of TFlatBtn;
    btnTab: array[0..7] of TFlatBtn;
    pages: array[0..7] of TPanel;
    edSearch: TEdit;
    cbSort, cbSector, cbLotBuy, cbLotSell: TComboBox;
    grid: TDrawGrid;
    reAnal, reMTF, reNews, reEdu, reLog, reCalc, reMT5: TRichEdit;
    lblMT5Conn, lblMT5Acc, lblMT5Pos, lblMT5Evt: TLabel;
    btnMT5Auto: TFlatBtn;
    FMT5Auto, FMT5Alive, FMT5First: Boolean;
    FMT5Seen: TStringList;
    FLotSynced: Boolean;
    lblMT5PL, lblMT5PLCap, lblRobot: TLabel;
    { koneksi MT5 + panel order manual (OPEN) }
    btnConn, btnOpen, btnOrdBuy, btnOrdSell, btnOrdMkt, btnOrdPend, btnOrdExec: TFlatBtn;
    pnlOrder: TPanel;
    lblOrdTitle, lblPendInfo, lblOrdRes: TLabel;
    pbSent: TPaintBox;
    edPend: TEdit;
    tbPend: TTrackBar;
    cbOrdLot: TComboBox;
    FOrdSide: Integer;
    FOrdPending, FPendSync, FMT5Old, FOrdMoved: Boolean;
    FFrontTicks: Integer;
    { tab Edukasi: pilihan Edukasi / Running Text + teks berjalan di bawah grafik }
    cbEduMode, cbRunSpeed: TComboBox;
    pnlEduRun, pnlRun: TPanel;
    memRun: TMemo;
    pbRun: TPaintBox;
    tmRun: TTimer;
    FRunText: string;
    FRunX: Integer;
    FRunHidden: Boolean;
    btnRunShow: TFlatBtn;
    { menu KONEKSI MT5: 1. Koneksi, 2. Kamera CCTV PH }
    pmConn: TPopupMenu;
    Cctv: TCctvView;
    { ubah ukuran panel OPEN dengan mouse (pegangan di pojok kanan bawah) }
    pnlOrdIn: TPanel;
    pbGrip: TPaintBox;
    lblOrdMsg: TLabel;
    btnOrdMsg: TFlatBtn;
    FOrdCtl: TList;
    FOrdBase: array of TRect;
    FOrdFont: array of Integer;
    FOrdScale: Double;
    FGripPt: TPoint;
    FGripW, FGripH: Integer;
    FPendBase, FMT5Bid, FMT5Ask: Double;
    FMT5Sym, FOrdID: string;
    FOrdAt: TDateTime;
    pbSess: TPaintBox;
    Chart: TChartView;
    tm1, tm30: TTimer;
    edRisk, edEntry, edSL, edTP, edLot, edLev: TEdit;
    edBal: TComboBox;
    btnBuyCalc, btnSellCalc: TFlatBtn;
    FCalcAutoLot: Double;

    FSym, FDispSym, FSrc: string;
    FIsGold, FFapiFail, FBusyLive, FBusyMTF, FBusyTick, FFirstSess: Boolean;
    FTF, FSeq, FCat, FTickN, FMainAlt, FCalcDir: Integer;
    FFapiRetry, FMainRetry: TDateTime;
    FTick, FView: TTickers;
    FGoldTick: TTicker;
    FHasGoldFut: Boolean;
    FCandles: TCandles;
    FMTF: array[0..6] of TCandles;
    FMTFInfo: array[0..6] of TTFInfo;
    FSessRange, FSessMove: array[0..3] of Double;
    FSig: TSignal;
    FSI: TStructInfo;
    FCross: TCrosses;
    FPats: TChartPats;
    RSI, MacdA, SigA, HistA, ATR: TDArr;
    FEvents: TEcoEvents;
    FSessOpen: array[0..3] of Boolean;
    FSessWarned: array[0..3] of TDateTime;
    FToastAt: TDateTime;
    FLastSigAlarm: Integer;
    { info sesi di bawah grafik + capture grafik }
    pnlInfo: TPanel;
    lblInfo1, lblInfo2, lblInfo3, lblCapNext: TLabel;
    FPhaseName: string;
    gridCap: TStringGrid;
    imgCap: TImage;
    pnlCapView: TPanel;
    lblCapView: TLabel;
    btnCapAuto: TFlatBtn;
    FCapList: TStringList;
    FCapKey: string;
    { rekam video layar }
    Rec: TScreenRecorder;
    btnRec, btnAutoRun: TFlatBtn;
    lblRec, lblRecInfo: TLabel;
    FVidBytes: Int64;

    procedure BuildUI;
    procedure BuildTop;
    procedure BuildLeft;
    procedure BuildRight;
    procedure BuildCalc(P: TPanel);
    procedure BuildEdu;
    function NewRE(P: TWinControl; Mono: Boolean): TRichEdit;
    function PipSize: Double;
    function PriceDigits: Integer;
    function KlineURLs(const TF: string; Limit: Integer): string;
    procedure SelectSymbol(const Sym: string; Gold: Boolean);
    procedure LoadMain;
    procedure LoadLive;
    procedure LoadMTF;
    procedure LoadTickers;
    procedure LoadCalendar;
    procedure FetchDone(T: TFetchThread);
    procedure Recompute(Full: Boolean);
    procedure UpdateHeader;
    procedure WriteAnalysis;
    procedure WriteMTF;
    procedure WriteNews;
    procedure ComputeSessRanges;
    procedure ApplyFilter;
    procedure Alarm(const Msg: string; Kind: Integer);
    procedure AddLog(const Msg: string; Col: TColor);
    procedure DoCalc;
    function TimeStrU(U: TDateTime): string;
    function HighImpactSoon(Minutes: Integer; out Ev: TEcoEvent): Boolean;

    procedure OnTF(Sender: TObject);
    procedure OnInd(Sender: TObject);
    procedure OnZoom(Sender: TObject);
    procedure OnGold(Sender: TObject);
    procedure OnLink(Sender: TObject);
    procedure BuildMT5(P: TPanel);
    procedure BuildCapture(P: TPanel);
    function CapDir: string;
    function SigText: string;
    procedure SaveCapList;
    procedure RefreshCapGrid;
    function DoCapture(const Mode: string): Boolean;
    procedure BuildVideo(P: TPanel);
    function VidDir: string;
    procedure UpdateRec;
    procedure OnRecBtn(Sender: TObject);
    procedure OnAutoRun(Sender: TObject);
    procedure OnVidFolder(Sender: TObject);
    procedure OnVidLast(Sender: TObject);
    procedure StopRecorder;
    procedure WMEndSession(var Msg: TWMEndSession); message WM_ENDSESSION;
    procedure OnLotStep(Sender: TObject);
    procedure OnLotRek(Sender: TObject);
    procedure UpdateSessInfo;
    procedure OnCapNow(Sender: TObject);
    procedure OnCapDel(Sender: TObject);
    procedure OnCapDelAll(Sender: TObject);
    procedure OnCapOpen(Sender: TObject);
    procedure OnCapFolder(Sender: TObject);
    procedure OnCapAuto(Sender: TObject);
    procedure OnCapSelect(Sender: TObject);
    procedure BuildCapView;
    procedure OnCapClose(Sender: TObject);
    procedure OnCapDraw(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure UpdateMT5;
    procedure MT5Guide;
    procedure BuildOrderPanel;
    procedure UpdateOrderPanel;
    function OrdPrice: Double;
    procedure OnConnBtn(Sender: TObject);
    procedure OnConnInfo(Sender: TObject);
    procedure OnCctvOpen(Sender: TObject);
    procedure OnCctvClosed(Sender: TObject);
    procedure OnOpenBtn(Sender: TObject);
    procedure OnOrdDrag(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure LayoutOrderPanel;
    procedure OnGripDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure OnGripMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure OnGripPaint(Sender: TObject);
    procedure OnOrdMsg(Sender: TObject);
    procedure OnOrdSide(Sender: TObject);
    procedure OnOrdMode(Sender: TObject);
    procedure OnPendStep(Sender: TObject);
    procedure OnPendTrack(Sender: TObject);
    procedure OnPendEdit(Sender: TObject);
    procedure OnOrdLotStep(Sender: TObject);
    procedure OnOrdExec(Sender: TObject);
    procedure OnSentPaint(Sender: TObject);
    procedure OnMT5Auto(Sender: TObject);
    procedure OnMT5Close(Sender: TObject);
    procedure OnMT5Install(Sender: TObject);
    procedure OnMT5Folder(Sender: TObject);
    procedure OnStopFer(Sender: TObject);
    procedure OnLotChange(Sender: TObject);
    function LotOf(C: TComboBox): Double;
    procedure OnAlarmBtn(Sender: TObject);
    procedure OnLeftToggle(Sender: TObject);
    procedure OnRightToggle(Sender: TObject);
    procedure OnCat(Sender: TObject);
    procedure OnTab(Sender: TObject);
    procedure OnSearch(Sender: TObject);
    procedure OnSort(Sender: TObject);
    procedure OnRefresh(Sender: TObject);
    procedure OnGridDraw(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure OnGridClick(Sender: TObject);
    procedure OnTimer1(Sender: TObject);
    procedure ForceFront;
    procedure BuildEduTab(P: TPanel);
    procedure OnEduMode(Sender: TObject);
    procedure OnRunChange(Sender: TObject);
    procedure OnRunClear(Sender: TObject);
    procedure OnRunShow(Sender: TObject);
    procedure OnRunTick(Sender: TObject);
    procedure OnRunPaint(Sender: TObject);
    procedure UpdateRunText;
    function RunFile: string;
    procedure OnTimer30(Sender: TObject);
    procedure OnSessPaint(Sender: TObject);
    procedure OnToastClick(Sender: TObject);
    procedure OnCalcBtn(Sender: TObject);
    procedure OnCalcDir(Sender: TObject);
    procedure OnCalcNow(Sender: TObject);
    procedure OnCalcSig(Sender: TObject);
    procedure AppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormResize(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

const
  SecMajor = ' BTC ETH BNB SOL XRP ADA DOGE TRX TON AVAX LINK DOT LTC BCH ';
  SecL1 = ' SOL ADA AVAX DOT NEAR APT SUI ATOM ALGO SEI TIA INJ FTM S HBAR ICP EGLD KAS TRX TON ETC XLM BNB ETH BTC ';
  SecL2 = ' ARB OP MATIC POL IMX STRK MNT ZK METIS MANTA LRC SKL CELO ';
  SecMeme = ' DOGE SHIB PEPE FLOKI BONK WIF BOME MEME TURBO NEIRO PNUT 1000SATS PEOPLE TRUMP 1MBABYDOGE ACT DOGS ';
  SecAI = ' FET RENDER TAO WLD AGIX OCEAN ARKM AI THETA GRT IO VIRTUAL NMR PHB AIXBT ';
  SecDeFi = ' UNI AAVE LINK MKR CRV LDO COMP SUSHI CAKE DYDX JUP PENDLE ENA 1INCH SNX RUNE GMX JOE ';
  SecGold = ' PAXG XAUT ';
  StableBases = ' USDC FDUSD TUSD BUSD DAI USDP EUR AEUR USDE EURI XUSD BFUSD USD1 ';

function Sx(B: Boolean; const A, C: string): string;
begin
  if B then Result := A else Result := C;
end;

function SgnI(V: Integer): string;
begin
  if V > 0 then Result := '+' + IntToStr(V) else Result := IntToStr(V);
end;

function Cx(B: Boolean; A, C: TColor): TColor;
begin
  if B then Result := A else Result := C;
end;

function DirCol(D: Integer): TColor;
begin
  if D > 0 then Result := clrGreen else if D < 0 then Result := clrRed else Result := clrMuted;
end;

function DirTxt(D: Integer): string;
begin
  if D > 0 then Result := 'BULLISH' else if D < 0 then Result := 'BEARISH' else Result := 'SIDEWAYS';
end;

{ ---------------- RichEdit helper ---------------- }

var
  REFirst: Integer;

procedure REBegin(RE: TRichEdit);
begin
  REFirst := SendMessage(RE.Handle, EM_GETFIRSTVISIBLELINE, 0, 0);
  RE.Lines.BeginUpdate;
  RE.Clear;
end;

procedure REEnd(RE: TRichEdit);
var cur: Integer;
begin
  RE.SelStart := 0;
  RE.Lines.EndUpdate;
  cur := SendMessage(RE.Handle, EM_GETFIRSTVISIBLELINE, 0, 0);
  SendMessage(RE.Handle, EM_LINESCROLL, 0, REFirst - cur);
end;

function IsAscii(const S: string): Boolean;
var i: Integer;
begin
  Result := True;
  for i := 1 to Length(S) do
    if Ord(S[i]) > 127 then begin Result := False; Exit; end;
end;

procedure REIn(RE: TRichEdit; const S: string; Col: TColor; Bold: Boolean = False; Size: Integer = 0;
  const FontName: string = '');
begin
  RE.SelStart := RE.GetTextLen;
  RE.SelLength := 0;
  if FontName <> '' then RE.SelAttributes.Name := FontName else RE.SelAttributes.Name := RE.Font.Name;
  RE.SelAttributes.Color := Col;
  if Bold then RE.SelAttributes.Style := [fsBold] else RE.SelAttributes.Style := [];
  if Size > 0 then RE.SelAttributes.Size := Size else RE.SelAttributes.Size := RE.Font.Size;
  RE.SelText := S;
end;

procedure REL(RE: TRichEdit; const S: string; Col: TColor; Bold: Boolean = False; Size: Integer = 0;
  const FontName: string = '');
begin
  REIn(RE, S + #13#10, Col, Bold, Size, FontName);
end;

procedure REH(RE: TRichEdit; const S: string);
begin
  REL(RE, '', clrText, False, 4);
  REL(RE, S, clrYellow, True, 10);
end;

procedure REKV(RE: TRichEdit; const K, V: string; Col: TColor);
begin
  REIn(RE, K, clrMuted);
  REL(RE, V, Col, True);
end;

{ ---------------- Suara alarm ---------------- }

constructor TBeepThread.Create(AKind: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FKind := AKind;
  Resume;
end;

procedure TBeepThread.Execute;
begin
  case FKind of
    1: begin Windows.Beep(784, 140); Windows.Beep(988, 140); Windows.Beep(1319, 260); end;
   -1: begin Windows.Beep(1319, 140); Windows.Beep(988, 140); Windows.Beep(659, 260); end;
    2: begin Windows.Beep(880, 200); Sleep(80); Windows.Beep(880, 200); end;
    3: begin Windows.Beep(1500, 120); Windows.Beep(1000, 120); Windows.Beep(1500, 120); Windows.Beep(1000, 300); end;
  else
    Windows.Beep(1000, 150);
  end;
end;

{ ---------------- Form ---------------- }

constructor TMainForm.Create(AOwner: TComponent);
var i: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'Fernanda Trading Recognito  -  SMC CHoCH | BOS | FVG  -  XAUUSDT & Crypto';
  Width := 1500; Height := 900;
  Position := poScreenCenter;
  WindowState := wsMaximized;
  Color := clrBg;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Font.Color := clrText;
  OnClose := FormClose;
  OnResize := FormResize;
  KeyPreview := True;
  FTF := 4; FCat := 0; FCalcDir := 1;
  FFirstSess := True;
  FLastSigAlarm := 0;
  for i := 0 to 3 do FSessWarned[i] := 0;
  BuildUI;
  Application.OnMessage := AppMessage;

  BuildBuiltinEvents(FEvents);
  LoadUserEvents(ExtractFilePath(ParamStr(0)) + 'events.txt', FEvents);
  SortEvents(FEvents);

  tm1 := TTimer.Create(Self);
  tm1.Interval := 1000;
  tm1.OnTimer := OnTimer1;
  tm30 := TTimer.Create(Self);
  tm30.Interval := 30000;
  tm30.OnTimer := OnTimer30;

  { perekam video layar: aktif kecuali dimatikan lewat tombol (disimpan di video.ini) }
  Rec := TScreenRecorder.Create(VidDir);
  with TStringList.Create do
  try
    if FileExists(CapDir + 'video.ini') then LoadFromFile(CapDir + 'video.ini');
    Rec.Enabled := Values['REKAM'] <> '0';
  finally
    Free;
  end;
  btnRec.Down := Rec.Enabled;
  btnRec.Caption := Sx(Rec.Enabled, 'REKAM VIDEO: ON', 'REKAM VIDEO: OFF');
  Rec.Resume;
  FVidBytes := FolderBytes(VidDir, 'Rekam_*.mp4');

  AddLog('Aplikasi dimulai. Alarm sinyal tiap 0,5 menit (30 detik) aktif.', clrYellow);
  FFapiFail := True;
  FFapiRetry := Now + 1;
  TFetchThread.Create(KIND_PROBE, 0, ['https://fapi.binance.com/fapi/v1/ping'], FetchDone);
  SelectSymbol('XAUUSDT', True);
  LoadTickers;
  LoadCalendar;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  AppClosing := True;
  tm1.Enabled := False;
  tm30.Enabled := False;
  StopRecorder;
end;

{ tutup file video dengan benar agar bisa diputar }
procedure TMainForm.StopRecorder;
begin
  if Rec = nil then Exit;
  Rec.Terminate;
  Rec.WaitFor;
  FreeAndNil(Rec);
end;

procedure TMainForm.WMEndSession(var Msg: TWMEndSession);
begin
  if Msg.EndSession then StopRecorder;
  inherited;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if Assigned(pnlToast) and Assigned(pnlCenter) then
    pnlToast.Left := (pnlCenter.Width - pnlToast.Width) div 2;
end;

function TMainForm.NewRE(P: TWinControl; Mono: Boolean): TRichEdit;
begin
  Result := TRichEdit.Create(Self);
  Result.Parent := P;
  Result.Align := alClient;
  Result.BorderStyle := bsNone;
  Result.Color := clrPanel;
  Result.ReadOnly := True;
  Result.ScrollBars := ssVertical;
  Result.HideSelection := True;
  Result.WordWrap := True;
  if Mono then Result.Font.Name := 'Consolas' else Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 9;
  Result.Font.Color := clrText;
end;

procedure TMainForm.BuildUI;
begin
  pnlStatus := MakePanel(Self, alBottom, 30, clrBg);
  with TLabel.Create(Self) do
  begin
    Parent := pnlStatus;
    Align := alRight;
    AutoSize := True;
    Layout := tlCenter;
    Caption := 'Created By: Fernanda Fatria Fatra,SST.MM   ';
    Font.Name := 'Segoe UI';
    Font.Size := 7;
    Font.Color := clWhite;
    Transparent := True;
  end;
  { kiri bawah: STOP FER + pilihan lot BUY / SELL untuk robot MT5 }
  with MakeBtn(pnlStatus, 'STOP FER', 6, 3, 92, 24, OnStopFer) do
  begin
    Bg := clrRed; Fg := clWhite; Bold := True;
  end;
  { robot dilarang beli / jual: pilihan lot robot disembunyikan }
  lblRobot := MakeLabel(pnlStatus, 'ORDER ROBOT: MATI  ' + #149 + '  aktifkan di chart MT5', 108, 8, RGB(255, 145, 0), 8, True);
  cbLotBuy := TComboBox.Create(Self);
  cbLotBuy.Visible := False;
  cbLotBuy.Parent := pnlStatus;
  cbLotBuy.Style := csDropDownList;
  cbLotBuy.SetBounds(158, 4, 62, 22);
  cbLotBuy.Color := clrPanel2; cbLotBuy.Font.Color := clrGreen; cbLotBuy.Font.Style := [fsBold];
  cbLotBuy.Items.CommaText := '0.01,0.02,0.03,0.05,0.10,0.20,0.30,0.50,1.00';
  cbLotBuy.ItemIndex := 0;
  cbLotBuy.OnChange := OnLotChange;
  cbLotSell := TComboBox.Create(Self);
  cbLotSell.Visible := False;
  cbLotSell.Parent := pnlStatus;
  cbLotSell.Style := csDropDownList;
  cbLotSell.SetBounds(282, 4, 62, 22);
  cbLotSell.Color := clrPanel2; cbLotSell.Font.Color := clrRed; cbLotSell.Font.Style := [fsBold];
  cbLotSell.Items.CommaText := '0.01,0.02,0.03,0.05,0.10,0.20,0.30,0.50,1.00';
  cbLotSell.ItemIndex := 0;
  cbLotSell.OnChange := OnLotChange;
  lblStatus := MakeLabel(pnlStatus, 'Menghubungkan ke Binance...', 356, 9, clrMuted, 7);

  BuildTop;

  pnlInd := MakePanel(Self, alTop, 32, clrPanel);
  { tombol tampil / sembunyikan panel kiri (EMAS/XAU + daftar koin) }
  btnLeft := MakeBtn(MakePanel(pnlInd, alLeft, 158, clrPanel), '<<  SEMBUNYIKAN KOIN', 8, 4, 146, 24, OnLeftToggle);
  btnLeft.BgDown := clrGold; btnLeft.FgDown := clrBg;
  btnLeft.Down := True;
  { tombol tampil / sembunyikan panel kanan (tab Analisa s/d Capture) }
  btnRight := MakeBtn(MakePanel(pnlInd, alRight, 176, clrPanel), 'SEMBUNYIKAN ANALISA  >>', 8, 4, 162, 24, OnRightToggle);
  btnRight.BgDown := clrGold; btnRight.FgDown := clrBg;
  btnRight.Down := True;
  pnlInd := MakePanel(pnlInd, alClient, 0, clrPanel);
  BuildLeft;
  BuildRight;

  pnlCenter := MakePanel(Self, alClient, 0, clrBg);

  { pesan waktu trading & persilangan sesi di bawah grafik }
  pnlInfo := MakePanel(pnlCenter, alBottom, 76, RGB(20, 24, 34));
  pnlInfo.BorderWidth := 4;
  lblInfo3 := MakeLabel(pnlInfo, '', 0, 40, clrText, 8);
  lblInfo2 := MakeLabel(pnlInfo, '', 0, 20, clrYellow, 9, True);
  lblInfo1 := MakeLabel(pnlInfo, 'Memuat jadwal sesi...', 0, 0, clrGreen, 10, True);
  lblInfo1.AutoSize := False; lblInfo1.Height := 19; lblInfo1.Align := alTop;
  lblInfo2.AutoSize := False; lblInfo2.Height := 18; lblInfo2.Align := alTop;
  lblInfo3.AutoSize := False; lblInfo3.Align := alClient;
  lblInfo3.WordWrap := True;

  { teks berjalan (running text) tepat di bawah grafik; tersembunyi bila teks kosong }
  pnlRun := MakePanel(pnlCenter, alBottom, 26, RGB(16, 20, 30));
  pnlRun.Top := 0;
  pnlRun.DoubleBuffered := True;
  pnlRun.Visible := False;
  pbRun := TPaintBox.Create(Self);
  pbRun.Parent := pnlRun;
  pbRun.Align := alClient;
  pbRun.OnPaint := OnRunPaint;
  tmRun := TTimer.Create(Self);
  tmRun.Interval := 30;
  tmRun.Enabled := False;
  tmRun.OnTimer := OnRunTick;
  if FileExists(ChangeFileExt(RunFile, '.ini')) then
    with TStringList.Create do
    try
      LoadFromFile(ChangeFileExt(RunFile, '.ini'));
      FRunHidden := Values['TAMPIL'] = '0';
    finally
      Free;
    end;
  if FileExists(RunFile) then memRun.Lines.LoadFromFile(RunFile);
  UpdateRunText;

  Chart := TChartView.Create(Self);
  Chart.Parent := pnlCenter;
  Chart.Align := alClient;
  Chart.LocalOffH := LocalOffsetH;
  BuildCapView;
  BuildOrderPanel;

  { Kamera CCTV PH: menutupi area grafik saat dibuka dari menu KONEKSI MT5 }
  Cctv := TCctvView.Create(Self);
  Cctv.Visible := False;
  Cctv.Parent := pnlCenter;
  Cctv.Align := alClient;
  Cctv.Setup(ExtractFilePath(ParamStr(0)) + 'cctv.ini');
  Cctv.OnCloseView := OnCctvClosed;
  pmConn := TPopupMenu.Create(Self);
  pmConn.Items.Add(NewItem('1.  Koneksi MT5', 0, False, True, OnConnInfo, 0, 'miConn'));
  pmConn.Items.Add(NewItem('2.  Kamera CCTV PH', 0, False, True, OnCctvOpen, 0, 'miCctv'));

  pnlToast := TPanel.Create(Self);
  pnlToast.Parent := pnlCenter;
  pnlToast.SetBounds(200, 60, 520, 62);
  pnlToast.BevelOuter := bvNone;
  pnlToast.ParentBackground := False;
  pnlToast.Color := clrPanel2;
  pnlToast.Visible := False;
  pnlToast.OnClick := OnToastClick;
  lblToast := MakeLabel(pnlToast, '', 14, 8, clrText, 10, True);
  lblToast.AutoSize := False;
  lblToast.WordWrap := True;
  lblToast.SetBounds(14, 6, 492, 52);
  lblToast.OnClick := OnToastClick;

  { tombol indikator }
  btnInd[0] := MakeBtn(pnlInd, 'MA9', 8, 4, 46, 24, OnInd, 0);
  btnInd[1] := MakeBtn(pnlInd, 'MA25', 56, 4, 46, 24, OnInd, 1);
  btnInd[2] := MakeBtn(pnlInd, 'MA99', 104, 4, 46, 24, OnInd, 2);
  btnInd[3] := MakeBtn(pnlInd, 'MA200', 152, 4, 50, 24, OnInd, 3);
  btnInd[4] := MakeBtn(pnlInd, 'MA500', 204, 4, 50, 24, OnInd, 4);
  btnInd[5] := MakeBtn(pnlInd, 'MA700', 256, 4, 50, 24, OnInd, 5);
  btnInd[6] := MakeBtn(pnlInd, 'BOLL', 316, 4, 46, 24, OnInd, 6);
  btnInd[7] := MakeBtn(pnlInd, 'S/R 1-3', 364, 4, 56, 24, OnInd, 7);
  btnInd[8] := MakeBtn(pnlInd, 'BOS/CHoCH', 422, 4, 72, 24, OnInd, 8);
  btnInd[9] := MakeBtn(pnlInd, 'FVG', 496, 4, 40, 24, OnInd, 9);
  btnInd[10] := MakeBtn(pnlInd, 'Pola', 538, 4, 40, 24, OnInd, 10);
  btnInd[11] := MakeBtn(pnlInd, 'Volume', 580, 4, 52, 24, OnInd, 11);
  MakeBtn(pnlInd, '+', 644, 4, 26, 24, OnZoom, 1);
  MakeBtn(pnlInd, '-', 672, 4, 26, 24, OnZoom, 2);
  MakeBtn(pnlInd, 'Reset', 700, 4, 44, 24, OnZoom, 3);
  btnAlarm := MakeBtn(pnlInd, 'ALARM 0,5 mnt: ON', 756, 4, 120, 24, OnAlarmBtn);
  btnAlarm.BgDown := clrRed; btnAlarm.FgDown := clWhite;
  btnAlarm.Down := True;
  lblSignal := MakeLabel(pnlInd, 'SINYAL: memuat...', 890, 6, clrYellow, 10, True);
  OnInd(nil);
end;

procedure TMainForm.BuildTop;
var i: Integer;
begin
  pnlTop := MakePanel(Self, alTop, 58, clrPanel);
  MakeLabel(pnlTop, 'FERNANDA TRADING', 14, 4, clrBlue, 15, True);
  MakeLabel(pnlTop, 'RECOGNITO  ' + #149 + '  SMC: CHoCH ' + #183 + ' BOS ' + #183 + ' FVG  ' + #149 + '  XAU', 16, 34, clrMuted, 8);

  btnGold := MakeBtn(pnlTop, 'XAUUSDT  EMAS', 262, 12, 120, 34, OnGold);
  btnGold.Bg := clrGold; btnGold.Fg := clrBg; btnGold.Bold := True;
  btnGold.BgDown := clrYellow;

  lblSym := MakeLabel(pnlTop, 'XAUUSDT', 396, 6, clrText, 12, True);
  lblPrice := MakeLabel(pnlTop, '-', 396, 26, clrGreen, 15, True);
  lblChg := MakeLabel(pnlTop, '', 540, 10, clrGreen, 9, True);
  lblCount := MakeLabel(pnlTop, '', 540, 32, clrMuted, 8);

  for i := 0 to 7 do
  begin
    btnTF[i] := MakeBtn(pnlTop, TFLabels[i], 650 + i * 40, 16, 38, 26, OnTF, i);
  end;
  btnTF[FTF].Down := True;

  { tautan broker / exchange }
  with MakeBtn(pnlTop, 'EXNESS', 984, 16, 70, 26, OnLink, 0) do
  begin
    Bg := RGB(255, 222, 2); Fg := clrBg; Bold := True;
  end;
  with MakeBtn(pnlTop, 'BINANCE', 1058, 16, 76, 26, OnLink, 1) do
  begin
    Bg := clrPanel2; Fg := clrYellow; Bold := True;
  end;
  with MakeBtn(pnlTop, 'TRADE WILL', 1138, 16, 86, 26, OnLink, 2) do
  begin
    Bg := RGB(0, 102, 204); Fg := clWhite; Bold := True;
  end;
  { koneksi MT5, untung / rugi order MT5 pengguna, dan tombol OPEN (order manual) }
  btnConn := MakeBtn(pnlTop, 'KONEKSI MT5', 1232, 16, 90, 26, OnConnBtn);
  btnConn.Bg := clrRedDim; btnConn.Fg := clWhite; btnConn.Bold := True;
  lblMT5PLCap := MakeLabel(pnlTop, 'UNTUNG / RUGI MT5', 1330, 6, clrMuted, 7, True);
  lblMT5PL := MakeLabel(pnlTop, '-', 1330, 18, clrMuted, 11, True);
  btnOpen := MakeBtn(pnlTop, 'OPEN', 1450, 16, 104, 26, OnOpenBtn);
  btnOpen.Bg := clrYellow; btnOpen.Fg := clrBg; btnOpen.Bold := True;
  btnOpen.BgDown := clrGold; btnOpen.FgDown := clrBg;

  pnlTopR := MakePanel(pnlTop, alRight, 360, clrPanel);
  lblClock := MakeLabel(pnlTopR, '--:--:--', 8, 2, clrText, 12, True);
  lblSess := MakeLabel(pnlTopR, 'Sesi: -', 8, 24, clrGreen, 8, True);
  lblSessNext := MakeLabel(pnlTopR, '', 8, 39, clrMuted, 8);
end;

procedure TMainForm.BuildLeft;
const Cats: array[0..5] of string = ('Semua', 'Top Gainer', 'Top Loser', 'Breakout', 'Breakdown', 'Volume');
var i: Integer; p: TPanel;
begin
  pnlLeft := MakePanel(Self, alLeft, 336, clrPanel);
  pnlLeft.BorderWidth := 0;

  pnlGold := MakePanel(pnlLeft, alTop, 66, RGB(38, 33, 16));
  MakeLabel(pnlGold, 'EMAS / XAU (khusus)', 10, 4, clrGold, 9, True);
  lblGoldPrice := MakeLabel(pnlGold, '-', 10, 22, clrText, 14, True);
  lblGoldChg := MakeLabel(pnlGold, '', 160, 28, clrGreen, 9, True);
  lblGoldSrc := MakeLabel(pnlGold, '', 10, 48, clrMuted, 7);

  p := MakePanel(pnlLeft, alTop, 34, clrPanel);
  MakeLabel(p, 'Cari koin:', 10, 9, clrMuted, 8);
  edSearch := TEdit.Create(Self);
  edSearch.Parent := p;
  edSearch.SetBounds(70, 6, 180, 22);
  edSearch.Color := clrPanel2;
  edSearch.Font.Color := clrText;
  edSearch.Font.Name := 'Segoe UI';
  edSearch.CharCase := ecUpperCase;
  edSearch.OnChange := OnSearch;
  MakeBtn(p, 'Refresh', 256, 5, 70, 24, OnRefresh);

  p := MakePanel(pnlLeft, alTop, 62, clrPanel);
  for i := 0 to 5 do
  begin
    btnCat[i] := MakeBtn(p, Cats[i], 8 + (i mod 3) * 108, 4 + (i div 3) * 28, 104, 24, OnCat, i);
    if i = 3 then begin btnCat[i].BgDown := clrGreen; end;
    if i = 4 then begin btnCat[i].BgDown := clrRed; btnCat[i].FgDown := clWhite; end;
  end;
  btnCat[0].Down := True;

  p := MakePanel(pnlLeft, alTop, 32, clrPanel);
  cbSector := TComboBox.Create(Self);
  cbSector.Parent := p;
  cbSector.Style := csDropDownList;
  cbSector.SetBounds(8, 4, 150, 22);
  cbSector.Color := clrPanel2; cbSector.Font.Color := clrText;
  cbSector.Items.CommaText := '"Kategori: Semua","Major","Layer 1","Layer 2","Meme","AI","DeFi","Emas / Komoditas"';
  cbSector.ItemIndex := 0;
  cbSector.OnChange := OnSort;
  cbSort := TComboBox.Create(Self);
  cbSort.Parent := p;
  cbSort.Style := csDropDownList;
  cbSort.SetBounds(164, 4, 164, 22);
  cbSort.Color := clrPanel2; cbSort.Font.Color := clrText;
  cbSort.Items.CommaText := '"Urut: Persen naik","Urut: Persen turun","Urut: Breakout","Urut: Breakdown","Urut: Volume","Urut: Nama"';
  cbSort.ItemIndex := 0;
  cbSort.OnChange := OnSort;

  grid := TDrawGrid.Create(Self);
  grid.Parent := pnlLeft;
  grid.Align := alClient;
  grid.BorderStyle := bsNone;
  grid.Color := clrPanel;
  grid.ColCount := 4;
  grid.RowCount := 2;
  grid.FixedRows := 1;
  grid.FixedCols := 0;
  grid.DefaultRowHeight := 24;
  grid.DefaultDrawing := False;
  grid.GridLineWidth := 0;
  grid.Options := [goRowSelect, goThumbTracking];
  grid.ScrollBars := ssVertical;
  grid.ColWidths[0] := 96;
  grid.ColWidths[1] := 84;
  grid.ColWidths[2] := 62;
  grid.ColWidths[3] := 74;
  grid.OnDrawCell := OnGridDraw;
  grid.OnClick := OnGridClick;
end;

procedure TMainForm.BuildRight;
const Tabs: array[0..7] of string = ('Analisa', 'Multi-TF', 'Sesi & Berita', 'Kalkulator', 'Edukasi', 'Alarm', 'MT5', 'Capture');
      TabW: array[0..7] of Integer = (50, 52, 72, 60, 50, 40, 40, 50);
var i, x: Integer; p: TPanel;
begin
  pnlRight := MakePanel(Self, alRight, 500, clrPanel);
  p := MakePanel(pnlRight, alTop, 32, clrPanel);
  x := 6;
  for i := 0 to 7 do
  begin
    btnTab[i] := MakeBtn(p, Tabs[i], x, 4, TabW[i] + 6, 24, OnTab, i);
    Inc(x, TabW[i] + 8);
  end;
  btnTab[6].Bg := RGB(255, 222, 2); btnTab[6].Fg := clrBg; btnTab[6].Bold := True;
  btnTab[7].Bg := clrBlue; btnTab[7].Fg := clWhite; btnTab[7].Bold := True;
  for i := 0 to 7 do
  begin
    pages[i] := MakePanel(pnlRight, alClient, 0, clrPanel);
    pages[i].BorderWidth := 6;
    pages[i].Visible := i = 0;
  end;
  btnTab[0].Down := True;

  reAnal := NewRE(pages[0], False);
  reMTF := NewRE(pages[1], False);

  pbSess := TPaintBox.Create(Self);
  pbSess.Parent := pages[2];
  pbSess.Align := alTop;
  pbSess.Height := 318;
  pbSess.OnPaint := OnSessPaint;
  reNews := NewRE(pages[2], False);

  BuildCalc(pages[3]);
  BuildEduTab(pages[4]);
  reLog := NewRE(pages[5], False);
  BuildMT5(pages[6]);
  BuildCapture(pages[7]);
  BuildEdu;
end;

{ ---------------- Capture grafik (otomatis tiap 4 jam) ---------------- }

const
  CapCols: array[0..6] of string = ('No', 'Waktu (WIB)', 'Nama Grafik', 'Sesi', 'Harga', 'Sinyal', 'Mode');
  CapColW: array[0..6] of Integer = (22, 98, 110, 78, 54, 64, 62);
  { blok 4 jam WIB, di-capture saat blok berakhir:
    05-09, 09-13, 13-17, 17-21, 21-01, 01-04 }
  CapEndH: array[0..5] of Integer = (9, 13, 17, 21, 1, 4);
  CapBlock: array[0..5] of string = ('05-09', '09-13', '13-17', '17-21', '21-01', '01-04');

{ blok yang berakhir pada jam W (menit 0..59), -1 bila bukan jam capture }
function CapBlockAt(W: TDateTime): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to 5 do
    if HourOf(W) = CapEndH[i] then begin Result := i; Exit; end;
end;

function NextCapAt(W: TDateTime): TDateTime;
var i, d: Integer; t: TDateTime;
begin
  Result := 0;
  for d := 0 to 1 do
    for i := 0 to 5 do
    begin
      t := Trunc(W) + d + CapEndH[i] / 24;
      if (t > W) and ((Result = 0) or (t < Result)) then Result := t;
    end;
end;

function SafeName(const S: string): string;
var i: Integer;
begin
  Result := S;
  for i := 1 to Length(Result) do
    if not (Result[i] in ['A'..'Z', 'a'..'z', '0'..'9', '-']) then Result[i] := '_';
end;

procedure TMainForm.BuildCapture(P: TPanel);
var f: TPanel; i: Integer;
begin
  FCapList := TStringList.Create;
  if FileExists(CapDir + 'capture.txt') then FCapList.LoadFromFile(CapDir + 'capture.txt');
  FCapKey := '';

  f := MakePanel(P, alTop, 104, clrPanel);
  MakeLabel(f, 'CAPTURE GRAFIK', 6, 0, clrYellow, 11, True);
  MakeLabel(f, '4 jam: 05-09, 09-13, 13-17, 17-21, 21-01, 01-04 WIB  +  tiap ganti sesi pasar', 6, 22, clrMuted, 8);
  lblCapNext := MakeLabel(f, '', 6, 38, clrText, 8, True);
  btnCapAuto := MakeBtn(f, 'AUTO 4 JAM: ON', 6, 58, 120, 26, OnCapAuto);
  btnCapAuto.BgDown := clrGreen; btnCapAuto.FgDown := clWhite;
  btnCapAuto.Down := True;
  with MakeBtn(f, 'CAPTURE SEKARANG', 132, 58, 130, 26, OnCapNow) do
  begin
    Bg := clrBlue; Fg := clWhite; Bold := True;
  end;
  with MakeBtn(f, 'HAPUS', 268, 58, 70, 26, OnCapDel) do
  begin
    Bg := clrRed; Fg := clWhite; Bold := True;
  end;
  with MakeBtn(f, 'HAPUS SEMUA', 344, 58, 96, 26, OnCapDelAll) do
  begin
    Bg := clrRedDim; Fg := clWhite;
  end;
  MakeBtn(f, 'Buka gambar', 268, 2, 82, 24, OnCapOpen);
  MakeBtn(f, 'Buka folder', 356, 2, 84, 24, OnCapFolder);
  MakeLabel(f, 'Klik baris = tampilkan capture di area grafik (TUTUP untuk kembali). Pilih baris lalu HAPUS.', 6, 88, clrMuted, 7);

  BuildVideo(P);

  gridCap := TStringGrid.Create(Self);
  gridCap.Parent := P;
  gridCap.Align := alClient;
  gridCap.BorderStyle := bsNone;
  gridCap.Color := clrPanel;
  gridCap.ColCount := 7;
  gridCap.RowCount := 2;
  gridCap.FixedRows := 1;
  gridCap.FixedCols := 0;
  gridCap.DefaultRowHeight := 22;
  gridCap.DefaultDrawing := False;
  gridCap.GridLineWidth := 0;
  gridCap.Options := [goRowSelect, goThumbTracking];
  for i := 0 to 6 do
  begin
    gridCap.ColWidths[i] := CapColW[i];
    gridCap.Cells[i, 0] := CapCols[i];
  end;
  gridCap.OnDrawCell := OnCapDraw;
  gridCap.OnClick := OnCapSelect;
  RefreshCapGrid;
end;

function TMainForm.CapDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'Capture\';
end;

function TMainForm.SigText: string;
begin
  case FSig.Action of
    2: Result := 'STRONG BUY';
    1: Result := 'BUY lemah';
   -1: Result := 'SELL lemah';
   -2: Result := 'STRONG SELL';
  else Result := 'WAIT';
  end;
end;

procedure TMainForm.SaveCapList;
begin
  ForceDirectories(CapDir);
  FCapList.SaveToFile(CapDir + 'capture.txt');
end;

{ satu baris capture.txt: waktu #9 nama #9 sesi #9 harga #9 sinyal #9 file #9 mode
  (ditampilkan terbaru di atas) }
procedure TMainForm.RefreshCapGrid;
var i, r, k: Integer; parts: TStringList;
begin
  parts := TStringList.Create;
  try
    if FCapList.Count = 0 then
    begin
      gridCap.RowCount := 2;
      for k := 0 to 6 do gridCap.Cells[k, 1] := '';
      gridCap.Cells[2, 1] := 'Belum ada capture';
    end
    else
    begin
      gridCap.RowCount := FCapList.Count + 1;
      for i := FCapList.Count - 1 downto 0 do
      begin
        r := FCapList.Count - i;
        parts.Text := StringReplace(FCapList[i], #9, #13#10, [rfReplaceAll]);
        while parts.Count < 7 do parts.Add('');
        gridCap.Cells[0, r] := IntToStr(i + 1);
        gridCap.Cells[1, r] := parts[0];
        gridCap.Cells[2, r] := parts[1];
        gridCap.Cells[3, r] := parts[2];
        gridCap.Cells[4, r] := parts[3];
        gridCap.Cells[5, r] := parts[4];
        gridCap.Cells[6, r] := parts[6];
        gridCap.Objects[0, r] := TObject(i);
      end;
    end;
  finally
    parts.Free;
  end;
  gridCap.Invalidate;
end;

procedure TMainForm.OnCapDraw(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
var cv: TCanvas; s: string; col: TColor;
begin
  cv := gridCap.Canvas;
  s := gridCap.Cells[ACol, ARow];
  if ARow = 0 then cv.Brush.Color := clrPanel2
  else if ARow = gridCap.Row then cv.Brush.Color := RGB(43, 49, 57)
  else cv.Brush.Color := clrPanel;
  cv.FillRect(Rect);
  cv.Font.Name := 'Segoe UI';
  cv.Font.Size := 8;
  col := clrText;
  if ARow = 0 then begin col := clrMuted; cv.Font.Style := [fsBold]; end
  else
  begin
    cv.Font.Style := [];
    if ACol = 2 then begin col := clrYellow; cv.Font.Style := [fsBold]; end;
    if ACol = 5 then
    begin
      if Pos('BUY', s) > 0 then col := clrGreen
      else if Pos('SELL', s) > 0 then col := clrRed
      else col := clrMuted;
    end;
    if (ACol = 0) or (ACol = 6) then col := clrMuted;
  end;
  cv.Font.Color := col;
  cv.Brush.Style := bsClear;
  cv.TextRect(Rect, Rect.Left + 4, Rect.Top + 4, s);
  cv.Brush.Style := bsSolid;
end;

function TMainForm.DoCapture(const Mode: string): Boolean;
var src, dst: TBitmap; jpg: TJPEGImage; ph: TWIBPhase; w: TDateTime;
    nm, fn, price, sess: string; y, n: Integer;
begin
  Result := False;
  n := Length(Chart.C);
  if (n = 0) or (Chart.ClientWidth < 50) or (Chart.ClientHeight < 50) then
  begin
    AddLog('Capture dilewati: data grafik belum termuat.', RGB(255, 145, 0));
    Exit;
  end;
  w := NowWIB;
  ph := GetWIBPhase(w);
  nm := FDispSym + ' ' + TFLabels[FTF];
  price := FmtP(Chart.C[n - 1].C, PriceDigits);
  sess := ph.Name;
  ForceDirectories(CapDir);
  fn := SafeName(nm) + '_' + FormatDateTime('yyyymmdd_hhnnss', w) + '.jpg';

  src := TBitmap.Create;
  dst := TBitmap.Create;
  jpg := TJPEGImage.Create;
  try
    Chart.Snapshot(src);
    dst.PixelFormat := pf24bit;
    dst.Width := src.Width;
    dst.Height := src.Height + 64;
    dst.Canvas.Draw(0, 0, src);
    { nama grafik + pesan sesi di bawah gambar }
    with dst.Canvas do
    begin
      Brush.Style := bsSolid;
      Brush.Color := RGB(20, 24, 34);
      FillRect(Rect(0, src.Height, dst.Width, dst.Height));
      Brush.Style := bsClear;
      Font.Name := 'Segoe UI';
      y := src.Height + 4;
      Font.Size := 10; Font.Style := [fsBold]; Font.Color := clrYellow;
      TextOut(8, y, 'GRAFIK: ' + nm + '   |   ' + FormatDateTime('dd/mm/yyyy hh:nn', w) + ' WIB   |   Harga ' +
        price + '   |   Sinyal ' + SigText + '   |   capture: ' + Mode);
      Font.Size := 9; Font.Color := clrGreen;
      TextOut(8, y + 20, 'Waktu trading: ' + ph.Name + ' (' + ph.Sessions + ')   ' + #149 + '   ' + ph.Cross);
      Font.Size := 8; Font.Style := []; Font.Color := clrText;
      TextOut(8, y + 40, 'Biasanya: ' + ph.Signal);
      Font.Color := clrMuted;
      TextOut(dst.Width - TextWidth('Fernanda Trading Recognito') - 8, y + 40, 'Fernanda Trading Recognito');
    end;
    jpg.CompressionQuality := 88;
    jpg.Assign(dst);
    jpg.SaveToFile(CapDir + fn);
  finally
    jpg.Free;
    dst.Free;
    src.Free;
  end;

  FCapList.Add(FormatDateTime('dd/mm/yyyy hh:nn', w) + #9 + nm + #9 + sess + #9 + price + #9 +
    SigText + #9 + fn + #9 + Mode);
  SaveCapList;
  RefreshCapGrid;
  gridCap.Row := 1;
  gridCap.Invalidate;
  AddLog(Format('Capture [%s]: %s (%s) disimpan ke Capture\%s', [Mode, nm, sess, fn]), clrBlue);
  Result := True;
end;

function CapIndex(G: TStringGrid; Count: Integer): Integer;
begin
  Result := -1;
  if (Count = 0) or (G.Row < 1) or (G.Row > Count) then Exit;
  Result := Integer(G.Objects[0, G.Row]);
end;

function CapFile(const Line: string): string;
var parts: TStringList;
begin
  parts := TStringList.Create;
  try
    parts.Text := StringReplace(Line, #9, #13#10, [rfReplaceAll]);
    if parts.Count >= 6 then Result := parts[5] else Result := '';
  finally
    parts.Free;
  end;
end;

{ tampilan capture menutupi grafik live sementara, tombol TUTUP mengembalikan }
procedure TMainForm.BuildCapView;
var bar, r: TPanel;
begin
  pnlCapView := MakePanel(pnlCenter, alClient, 0, clrBg);
  pnlCapView.Visible := False;
  bar := MakePanel(pnlCapView, alTop, 36, clrPanel2);
  r := MakePanel(bar, alRight, 250, clrPanel2);
  with MakeBtn(r, 'X  TUTUP  (kembali ke grafik)', 6, 5, 236, 26, OnCapClose) do
  begin
    Bg := clrRed; Fg := clWhite; Bold := True;
  end;
  lblCapView := MakeLabel(bar, '', 10, 8, clrYellow, 10, True);

  imgCap := TImage.Create(Self);
  imgCap.Parent := pnlCapView;
  imgCap.Align := alClient;
  imgCap.Stretch := True;
  imgCap.Proportional := True;
  imgCap.Center := True;
  imgCap.OnDblClick := OnCapOpen;
end;

procedure TMainForm.OnCapClose(Sender: TObject);
begin
  if not Assigned(pnlCapView) then Exit;
  pnlCapView.Visible := False;
  imgCap.Picture := nil;
  Chart.Visible := True;
  Chart.Invalidate;
end;

procedure TMainForm.OnCapSelect(Sender: TObject);
var k: Integer; fn: string;
begin
  gridCap.Invalidate;
  k := CapIndex(gridCap, FCapList.Count);
  if k < 0 then Exit;
  fn := CapDir + CapFile(FCapList[k]);
  if not FileExists(fn) then
  begin
    AddLog('File capture tidak ditemukan: ' + fn, clrRed);
    Exit;
  end;
  try
    imgCap.Picture.LoadFromFile(fn);
  except
    AddLog('Gagal membuka capture: ' + fn, clrRed);
    Exit;
  end;
  lblCapView.Caption := 'CAPTURE: ' + gridCap.Cells[2, gridCap.Row] + '   ' + #149 + '   ' +
    gridCap.Cells[1, gridCap.Row] + ' WIB   ' + #149 + '   ' + gridCap.Cells[3, gridCap.Row] + '   ' + #149 +
    '   ' + gridCap.Cells[5, gridCap.Row] + '   (' + gridCap.Cells[6, gridCap.Row] + ')';
  Chart.Visible := False;
  pnlCapView.Visible := True;
  pnlCapView.BringToFront;
  if pnlToast.Visible then pnlToast.BringToFront;
end;

procedure TMainForm.OnCapNow(Sender: TObject);
begin
  DoCapture('Manual');
end;

procedure TMainForm.OnCapDel(Sender: TObject);
var k: Integer; fn: string;
begin
  k := CapIndex(gridCap, FCapList.Count);
  if k < 0 then Exit;
  if MessageDlg('Hapus capture "' + gridCap.Cells[2, gridCap.Row] + '" jam ' + gridCap.Cells[1, gridCap.Row] + '?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  fn := CapDir + CapFile(FCapList[k]);
  if FileExists(fn) then DeleteFile(fn);
  FCapList.Delete(k);
  SaveCapList;
  RefreshCapGrid;
  OnCapClose(nil);
end;

procedure TMainForm.OnCapDelAll(Sender: TObject);
var i: Integer; fn: string;
begin
  if FCapList.Count = 0 then Exit;
  if MessageDlg(Format('Hapus SEMUA %d capture beserta gambarnya?', [FCapList.Count]),
    mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  for i := 0 to FCapList.Count - 1 do
  begin
    fn := CapDir + CapFile(FCapList[i]);
    if FileExists(fn) then DeleteFile(fn);
  end;
  FCapList.Clear;
  SaveCapList;
  RefreshCapGrid;
  OnCapClose(nil);
end;

procedure TMainForm.OnCapOpen(Sender: TObject);
var k: Integer; fn: string;
begin
  k := CapIndex(gridCap, FCapList.Count);
  if k < 0 then Exit;
  fn := CapDir + CapFile(FCapList[k]);
  if FileExists(fn) then ShellExecute(Handle, 'open', PChar(fn), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.OnCapFolder(Sender: TObject);
begin
  ForceDirectories(CapDir);
  ShellExecute(Handle, 'open', PChar(CapDir), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.OnCapAuto(Sender: TObject);
begin
  btnCapAuto.Down := not btnCapAuto.Down;
  btnCapAuto.Caption := Sx(btnCapAuto.Down, 'AUTO 4 JAM: ON', 'AUTO 4 JAM: OFF');
  AddLog('Capture otomatis (4 jam + ganti sesi) ' + Sx(btnCapAuto.Down, 'diaktifkan.', 'dimatikan.'), clrBlue);
end;

procedure TMainForm.UpdateSessInfo;
var w, nx: TDateTime; ph: TWIBPhase; b: Integer; changed: Boolean; mode, key: string;
begin
  w := NowWIB;
  ph := GetWIBPhase(w);
  nx := NextWIBPhaseAt(w);
  lblInfo1.Caption := 'WAKTU TRADING: ' + ph.Name + '   (' + ph.Sessions + ' WIB)   ' + #149 +
    '   berganti ' + FormatDateTime('hh:nn', nx) + ' WIB (dalam ' + CountdownStr((nx - w) * 86400) + ')';
  lblInfo2.Caption := 'PERSILANGAN: ' + ph.Cross;
  lblInfo3.Caption := 'SINYAL BIASANYA: ' + ph.Signal + '   |   Sinyal sekarang ' + FDispSym + ' ' + TFLabels[FTF] + ': ' + SigText;
  case ph.Idx of
    6: lblInfo1.Font.Color := RGB(255, 145, 0);
    3, 4: lblInfo1.Font.Color := clrYellow;
   -1, 1: lblInfo1.Font.Color := clrMuted;
  else lblInfo1.Font.Color := clrGreen;
  end;
  changed := (FPhaseName <> '') and (FPhaseName <> ph.Name);
  if changed then
    Alarm('WAKTU TRADING: ' + ph.Name + ' - ' + ph.Cross + '. ' + ph.Signal, 2);
  FPhaseName := ph.Name;

  lblCapNext.Caption := Sx(btnCapAuto.Down, 'Capture 4 jam berikutnya: ' +
    FormatDateTime('dd/mm hh:nn', NextCapAt(w)) + ' WIB  (' + IntToStr(FCapList.Count) + ' tersimpan)',
    'Capture otomatis MATI  (' + IntToStr(FCapList.Count) + ' tersimpan)');
  if not btnCapAuto.Down then Exit;

  { capture otomatis: akhir blok 4 jam dan setiap pergantian sesi pasar.
    Dicoba selama menit pertama jam capture, sampai data grafik siap. }
  mode := '';
  b := CapBlockAt(w);
  key := '';
  if (b >= 0) and (MinuteOf(w) = 0) then
  begin
    key := FormatDateTime('yyyymmddhh', w);
    if key <> FCapKey then mode := '4 jam ' + CapBlock[b];
  end;
  if changed then
  begin
    if mode <> '' then mode := mode + ' + ';
    mode := mode + 'Sesi';
  end;
  if (mode <> '') and DoCapture(mode) and (key <> '') then FCapKey := key;
end;

{ ---------------- Rekam video layar ---------------- }

const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  RunName = 'RecognitoTradingFernanda';

function AutoRunOn: Boolean;
begin
  Result := False;
  with TRegistry.Create do
  try
    RootKey := HKEY_CURRENT_USER;
    if OpenKeyReadOnly(RunKey) then Result := ValueExists(RunName);
  finally
    Free;
  end;
end;

function SizeStr(B: Int64): string;
begin
  if B >= 1024 * 1024 * 1024 then Result := FormatFloat('0.00', B / (1024 * 1024 * 1024)) + ' GB'
  else Result := FormatFloat('0', B / (1024 * 1024)) + ' MB';
end;

function TMainForm.VidDir: string;
begin
  Result := CapDir + 'Video\';
end;

procedure TMainForm.BuildVideo(P: TPanel);
var f: TPanel;
begin
  f := MakePanel(P, alTop, 96, RGB(20, 24, 34));
  f.Top := 2000;
  f.BorderWidth := 2;
  MakeLabel(f, 'REKAM VIDEO LAYAR', 6, 2, clrYellow, 11, True);
  MakeLabel(f, 'MP4 - semua aktivitas di layar, otomatis selama komputer & aplikasi aktif', 160, 6, clrMuted, 7);
  btnRec := MakeBtn(f, 'REKAM VIDEO: ON', 6, 26, 120, 26, OnRecBtn);
  btnRec.BgDown := clrRed; btnRec.FgDown := clWhite;
  btnRec.Down := True;
  btnAutoRun := MakeBtn(f, '', 132, 26, 168, 26, OnAutoRun);
  btnAutoRun.BgDown := clrGreen; btnAutoRun.FgDown := clWhite;
  btnAutoRun.Down := AutoRunOn;
  btnAutoRun.Caption := Sx(btnAutoRun.Down, 'NYALA SAAT WINDOWS: ON', 'NYALA SAAT WINDOWS: OFF');
  MakeBtn(f, 'Folder video', 306, 26, 84, 26, OnVidFolder);
  MakeBtn(f, 'Putar terakhir', 396, 26, 90, 26, OnVidLast);
  lblRec := MakeLabel(f, 'Menyiapkan perekam...', 6, 58, clrMuted, 8, True);
  lblRecInfo := MakeLabel(f, '', 6, 76, clrMuted, 7);
end;

procedure TMainForm.UpdateRec;
var st, cur, err: string; isRec: Boolean; t0: TDateTime; w, h: Integer; tot: Int64;
begin
  if Rec = nil then Exit;
  Rec.GetInfo(st, cur, err, isRec, t0, w, h, tot);
  if SecondOf(Now) mod 10 = 0 then FVidBytes := FolderBytes(VidDir, 'Rekam_*.mp4');
  if isRec then
  begin
    lblRec.Caption := #149 + ' REC  ' + FormatDateTime('hh:nn:ss', Now - t0) + '   ' + ExtractFileName(cur);
    lblRec.Font.Color := Cx(SecondOf(Now) mod 2 = 0, clrRed, RGB(255, 145, 0));
  end
  else
  begin
    lblRec.Caption := st;
    lblRec.Font.Color := Cx(err <> '', clrRed, clrMuted);
  end;
  lblRecInfo.Caption := Format('%dx%d, %d fps, file baru tiap %d menit   %s   folder %s / batas %s (terlama dihapus otomatis)',
    [w, h, Rec.Fps, Rec.SegMinutes, #149, SizeStr(FVidBytes), SizeStr(Rec.MaxBytes)]);
  if (err <> '') and not isRec then lblRecInfo.Caption := 'Error: ' + err;
end;

procedure TMainForm.OnRecBtn(Sender: TObject);
begin
  if Rec = nil then Exit;
  btnRec.Down := not btnRec.Down;
  btnRec.Caption := Sx(btnRec.Down, 'REKAM VIDEO: ON', 'REKAM VIDEO: OFF');
  Rec.Enabled := btnRec.Down;
  ForceDirectories(CapDir);
  with TStringList.Create do
  try
    Values['REKAM'] := Sx(btnRec.Down, '1', '0');
    SaveToFile(CapDir + 'video.ini');
  finally
    Free;
  end;
  AddLog('Rekam video layar ' + Sx(btnRec.Down, 'diaktifkan.', 'dimatikan (file terakhir ditutup).'), clrBlue);
end;

procedure TMainForm.OnAutoRun(Sender: TObject);
var turnOn: Boolean;
begin
  turnOn := not btnAutoRun.Down;
  with TRegistry.Create do
  try
    RootKey := HKEY_CURRENT_USER;
    if OpenKey(RunKey, True) then
    begin
      if turnOn then WriteString(RunName, '"' + ParamStr(0) + '"')
      else if ValueExists(RunName) then DeleteValue(RunName);
    end;
  finally
    Free;
  end;
  btnAutoRun.Down := AutoRunOn;
  btnAutoRun.Caption := Sx(btnAutoRun.Down, 'NYALA SAAT WINDOWS: ON', 'NYALA SAAT WINDOWS: OFF');
  AddLog(Sx(btnAutoRun.Down, 'Aplikasi akan berjalan (dan merekam) otomatis saat Windows menyala.',
    'Aplikasi tidak lagi berjalan otomatis saat Windows menyala.'), clrBlue);
end;

procedure TMainForm.OnVidFolder(Sender: TObject);
begin
  ForceDirectories(VidDir);
  ShellExecute(Handle, 'open', PChar(VidDir), nil, nil, SW_SHOWNORMAL);
end;

{ putar video terakhir yang sudah selesai (file yang sedang direkam belum bisa diputar) }
procedure TMainForm.OnVidLast(Sender: TObject);
var sl: TStringList; sr: TSearchRec; st, cur, err: string; isRec: Boolean; t0: TDateTime; w, h, i: Integer; tot: Int64;
begin
  cur := '';
  if Rec <> nil then Rec.GetInfo(st, cur, err, isRec, t0, w, h, tot);
  sl := TStringList.Create;
  try
    if FindFirst(VidDir + 'Rekam_*.mp4', faAnyFile, sr) = 0 then
    begin
      repeat
        if not SameText(VidDir + sr.Name, cur) then sl.Add(sr.Name);
      until FindNext(sr) <> 0;
      FindClose(sr);
    end;
    sl.Sort;
    if sl.Count = 0 then
    begin
      AddLog('Belum ada video selesai. File baru selesai tiap ' + IntToStr(Rec.SegMinutes) +
        ' menit (atau matikan REKAM sebentar untuk menutup file).', RGB(255, 145, 0));
      Exit;
    end;
    i := sl.Count - 1;
    ShellExecute(Handle, 'open', PChar(VidDir + sl[i]), nil, nil, SW_SHOWNORMAL);
  finally
    sl.Free;
  end;
end;

procedure TMainForm.BuildMT5(P: TPanel);
var f: TPanel;
begin
  FMT5Seen := TStringList.Create;
  FMT5First := True;
  f := MakePanel(P, alTop, 214, clrPanel);
  MakeLabel(f, 'MT5 (EXNESS) - ORDER ROBOT ATAS PERINTAH PENGGUNA', 6, 0, clrYellow, 11, True);
  lblMT5Conn := MakeLabel(f, 'EA belum terhubung', 6, 24, clrRed, 9, True);
  lblMT5Acc := MakeLabel(f, '', 6, 44, clrText, 8);
  lblMT5Pos := MakeLabel(f, '', 6, 60, clrText, 8, True);
  lblMT5Evt := MakeLabel(f, '', 6, 76, clrMuted, 8);
  MakeLabel(f, 'Order robot MATI sampai Anda klik AKTIFKAN ORDER di chart MT5. Aplikasi hanya bisa menghentikan.', 6, 94, clrMuted, 7);
  btnMT5Auto := MakeBtn(f, 'ORDER ROBOT: MATI', 6, 114, 206, 36, OnMT5Auto);
  btnMT5Auto.Bold := True;
  btnMT5Auto.BgDown := clrGreen; btnMT5Auto.FgDown := clWhite;
  with MakeBtn(f, 'TUTUP SEMUA POSISI', 218, 114, 206, 36, OnMT5Close) do
  begin
    Bg := clrRed; Fg := clWhite; Bold := True;
  end;
  MakeBtn(f, 'Pasang EA ke MT5', 6, 158, 206, 26, OnMT5Install);
  MakeBtn(f, 'Buka folder EA', 218, 158, 206, 26, OnMT5Folder);
  MakeLabel(f, 'Uji dulu di akun DEMO sebelum memakai akun real.', 6, 192, RGB(255, 145, 0), 8, True);
  reMT5 := NewRE(P, False);
  MT5Guide;
end;

procedure TMainForm.MT5Guide;
var R: TRichEdit;
begin
  R := reMT5;
  REL(R, 'CARA MENYAMBUNGKAN KE MT5 EXNESS', clrYellow, True, 10);
  REL(R, '1. Buka MT5 Exness dan login ke akun Anda (disarankan akun DEMO dulu).', clrText);
  REL(R, '2. Klik "Pasang EA ke MT5" di atas (atau salin RecognitoBridge.mq5 ke folder MQL5\Experts).', clrText);
  REL(R, '3. Di MT5: Navigator > Expert Advisors > klik kanan > Refresh. Bila belum muncul, buka', clrText);
  REL(R, '   MetaEditor (F4), buka RecognitoBridge.mq5 lalu tekan F7 (Compile).', clrText);
  REL(R, '4. Buka chart XAUUSD (Exness: XAUUSDm / XAUUSD) dengan timeframe yang diinginkan.', clrText);
  REL(R, '5. Seret EA RecognitoBridge ke chart, centang "Allow Algo Trading", klik OK.', clrText);
  REL(R, '6. Pastikan tombol "Algo Trading" di toolbar MT5 berwarna hijau.', clrText);
  REL(R, '7. Status di atas berubah menjadi TERHUBUNG, dan order Anda tampil di bawah grafik.', clrText);
  REL(R, '', clrText);
  REL(R, 'ORDER ROBOT ATAS PERINTAH PENGGUNA', clrYellow, True, 10);
  REL(R, '  Saat EA dipasang, order robot SELALU MATI. Robot tidak membuka BUY / SELL sendiri.', clrText);
  REL(R, '  Mengaktifkan: klik AKTIFKAN ORDER di chart MT5, lalu pilih Yes pada konfirmasi.', clrText);
  REL(R, '  Menghentikan: klik tombol itu lagi di MT5, atau STOP FER / tombol ORDER ROBOT di aplikasi.', clrText);
  REL(R, '  Saat aktif: BUY saat BuE / CHoCH naik (tutup di BBC ke-3), SELL saat BeE / CHoCH turun (tutup di BWS ke-3).', clrMuted);
  REL(R, '', clrText);
  REL(R, 'LOG EA MT5', clrYellow, True, 10);
end;

procedure TMainForm.UpdateMT5;
var sl, f: TStringList; age, tot: Double; ok, isNew: Boolean; i, k, npos: Integer; s, v: string;
    lines: TPosLines;
begin
  sl := TStringList.Create;
  try
    ok := MT5ReadStatus(sl, age);
    FMT5Alive := ok and (age < 8) and (sl.Values['EA'] = 'ON');
    if FMT5Alive then
    begin
      FMT5Auto := sl.Values['AUTO'] = '1';
      if not FLotSynced then
      begin
        { tampilkan lot yang sedang dipakai robot }
        if cbLotBuy.Items.IndexOf(sl.Values['LOTBUY']) >= 0 then cbLotBuy.ItemIndex := cbLotBuy.Items.IndexOf(sl.Values['LOTBUY']);
        if cbLotSell.Items.IndexOf(sl.Values['LOTSELL']) >= 0 then cbLotSell.ItemIndex := cbLotSell.Items.IndexOf(sl.Values['LOTSELL']);
        FLotSynced := True;
      end;
      if sl.Values['ALGO'] = '1' then
      begin
        lblMT5Conn.Caption := 'TERHUBUNG: EA aktif di ' + sl.Values['SYMBOL'] + ' ' + sl.Values['TF'];
        lblMT5Conn.Font.Color := clrGreen;
      end
      else
      begin
        lblMT5Conn.Caption := 'TERHUBUNG, tetapi tombol Algo Trading MT5 MATI!';
        lblMT5Conn.Font.Color := RGB(255, 145, 0);
      end;
      lblMT5Acc.Caption := Format('Akun %s  (%s)   Balance %s   Equity %s %s',
        [sl.Values['ACCOUNT'], sl.Values['SERVER'], sl.Values['BALANCE'], sl.Values['EQUITY'], sl.Values['CURRENCY']]);
      v := sl.Values['PROFIT'];
      lblMT5Pos.Caption := Format('Posisi EA:  BUY %s   SELL %s   P/L %s', [sl.Values['POS_BUY'], sl.Values['POS_SELL'], v]);
      lblMT5Pos.Font.Color := DirCol(Sign(PF(v)));
      lblMT5Evt.Caption := 'Event terakhir: ' + sl.Values['LASTEVT'] + '   ' + #149 + '   Harga MT5: ' + sl.Values['PRICE'];
    end
    else
    begin
      FMT5Auto := False;   { EA tidak jalan = robot tidak bisa order }
      if ok and (sl.Values['EA'] = 'OFF') then lblMT5Conn.Caption := 'EA di MT5 sudah dihentikan'
      else lblMT5Conn.Caption := 'EA belum terhubung - pasang & jalankan EA di MT5';
      lblMT5Conn.Font.Color := clrRed;
      lblMT5Acc.Caption := '';
      lblMT5Pos.Caption := '';
      lblMT5Evt.Caption := '';
    end;
    btnMT5Auto.Down := FMT5Auto;
    btnMT5Auto.Caption := Sx(FMT5Auto, 'ORDER ROBOT AKTIF (klik = stop)', 'ORDER ROBOT: MATI');
    lblRobot.Caption := Sx(FMT5Auto, 'ORDER ROBOT: AKTIF (diaktifkan di MT5)  ' + #149 + '  STOP FER = hentikan',
      'ORDER ROBOT: MATI  ' + #149 + '  aktifkan di chart MT5');
    lblRobot.Font.Color := Cx(FMT5Auto, clrGreen, RGB(255, 145, 0));

    if ok then
      for i := 0 to sl.Count - 1 do
        if Copy(sl[i], 1, 4) = 'LOG=' then
        begin
          s := Copy(sl[i], 5, MaxInt);
          isNew := FMT5Seen.IndexOf(s) < 0;
          if not isNew then Continue;
          FMT5Seen.Add(s);
          if FMT5Seen.Count > 300 then FMT5Seen.Delete(0);
          REL(reMT5, s, Cx(Pos('GAGAL', s) > 0, clrRed, Cx(Pos('BUY', s) > 0, clrGreen, Cx(Pos('SELL', s) > 0, RGB(255, 110, 125), clrText))));
          SendMessage(reMT5.Handle, EM_SCROLLCARET, 0, 0);
          if FMT5First then Continue;
          if (Pos('DIBUKA', s) > 0) or (Pos('DITUTUP', s) > 0) or (Pos('GAGAL', s) > 0) then
          begin
            if Pos('BUY', s) > 0 then Alarm('MT5: ' + s, 1) else Alarm('MT5: ' + s, -1);
          end
          else AddLog('MT5: ' + s, clrMuted);
        end;
    FMT5First := False;

    { untung / rugi semua posisi akun MT5 (termasuk order manual), di sebelah TRADE WILL,
      dan garis kuning harga open posisi XAU di grafik }
    tot := 0; npos := 0;
    SetLength(lines, 0);
    f := TStringList.Create;
    try
      if FMT5Alive then
        for i := 0 to sl.Count - 1 do
          if Copy(sl[i], 1, 6) = 'ACPOS=' then
          begin
            { ACPOS=tiket;jenis;lot;simbol;open;kini;sl;tp;P/L;asal }
            f.Text := StringReplace(Copy(sl[i], 7, MaxInt), ';', #13#10, [rfReplaceAll]);
            if f.Count < 9 then Continue;
            tot := tot + PF(f[8]);
            Inc(npos);
            k := Length(FCandles);
            if FIsGold and (k > 0) and (Pos('XAU', UpperCase(f[3])) > 0) and (PF(f[5]) > 0) then
            begin
              { grafik memakai harga Binance: garis digambar pada jarak yang sama dari harga grafik }
              SetLength(lines, Length(lines) + 1);
              lines[High(lines)].Price := FCandles[k - 1].C + (PF(f[4]) - PF(f[5]));
              lines[High(lines)].Lbl := Format('%s %s @ %s   P/L %s', [f[1], f[2], f[4],
                FormatFloat('+#,##0.00;-#,##0.00;0.00', PF(f[8]))]);
            end;
          end;
    finally
      f.Free;
    end;
    Chart.PosLines := lines;
    Chart.Invalidate;
    if not FMT5Alive then
    begin
      lblMT5PL.Font.Size := 9;
      lblMT5PL.Caption := 'MT5 belum terhubung';
      lblMT5PL.Font.Color := clrMuted;
    end
    else if npos = 0 then
    begin
      lblMT5PL.Font.Size := 9;
      lblMT5PL.Caption := 'Tidak ada posisi';
      lblMT5PL.Font.Color := clrMuted;
    end
    else
    begin
      lblMT5PL.Font.Size := 11;
      lblMT5PL.Caption := FormatFloat('+#,##0.00;-#,##0.00;0.00', tot) + ' ' + sl.Values['CURRENCY'];
      lblMT5PL.Font.Color := DirCol(Sign(tot));
    end;
    lblMT5PLCap.Caption := 'UNTUNG / RUGI MT5' + Sx(npos > 0, Format(' (%d)', [npos]), '');
    btnConn.Bg := Cx(FMT5Alive, clrGreenDim, clrRedDim);
    btnConn.Invalidate;

    { harga MT5 untuk panel order + hasil order yang sedang ditunggu }
    if FMT5Alive then
    begin
      FMT5Bid := PF(sl.Values['PRICE']);
      FMT5Ask := PF(sl.Values['ASK']);
      FMT5Old := sl.IndexOfName('ORDACK') < 0;   { EA versi lama: belum bisa menerima order }
      if FMT5Ask <= 0 then FMT5Ask := FMT5Bid;
      FMT5Sym := sl.Values['SYMBOL'];
      v := sl.Values['ORDACK'];
      if (FOrdID <> '') and (Copy(v, 1, Length(FOrdID) + 1) = FOrdID + ';') then
      begin
        Delete(v, 1, Length(FOrdID) + 1);
        if Copy(v, 1, 3) = 'OK;' then
        begin
          lblOrdRes.Caption := 'BERHASIL: ' + Copy(v, 4, MaxInt);
          lblOrdRes.Font.Color := clrGreen;
        end
        else
        begin
          lblOrdRes.Caption := 'GAGAL: ' + Copy(v, 6, MaxInt);
          lblOrdRes.Font.Color := clrRed;
        end;
        FOrdID := '';
      end;
    end
    else
    begin
      FMT5Bid := 0; FMT5Ask := 0; FMT5Sym := '';
    end;
    if (FOrdID <> '') and (Now - FOrdAt > 25 / 86400) then
    begin
      lblOrdRes.Caption := 'Tidak ada jawaban dari EA MT5 - periksa MT5 (order mungkin tidak terkirim).';
      lblOrdRes.Font.Color := RGB(255, 145, 0);
      FOrdID := '';
    end;
    UpdateOrderPanel;
  finally
    sl.Free;
  end;
end;

{ ---------------- Koneksi MT5 + order manual pengguna (tombol OPEN) ---------------- }

{ tombol KONEKSI MT5 membuka dropdown: 1. Koneksi, 2. Kamera CCTV PH }
procedure TMainForm.OnConnBtn(Sender: TObject);
var pt: TPoint;
begin
  pt := btnConn.ClientToScreen(Point(0, btnConn.Height));
  pmConn.Popup(pt.X, pt.Y);
end;

procedure TMainForm.OnCctvOpen(Sender: TObject);
begin
  OnCapClose(nil);
  Chart.Visible := False;
  Cctv.OpenView;
  if pnlOrder.Visible then pnlOrder.BringToFront;
end;

procedure TMainForm.OnCctvClosed(Sender: TObject);
begin
  Chart.Visible := True;
  Chart.Invalidate;
end;

procedure TMainForm.OnConnInfo(Sender: TObject);
begin
  if FMT5Alive then
    MessageDlg('Sudah terhubung Fatra73' + #13#10#13#10 + lblMT5Acc.Caption + #13#10 + lblMT5Conn.Caption,
      mtInformation, [mbOK], 0)
  else
    MessageDlg('Belom terhubung lagi ngambek Ho' + #13#10#13#10 +
      'Buka MT5, login, lalu seret EA RecognitoBridge ke chart (lihat tab MT5).', mtWarning, [mbOK], 0);
end;

procedure TMainForm.BuildOrderPanel;
var outer, f: TPanel; i: Integer;
begin
  FOrdSide := 1;
  FOrdPending := False;
  outer := MakePanel(pnlCenter, alNone, 0, clrYellow);
  outer.SetBounds(0, 0, 312, 372);
  outer.BorderWidth := 1;
  outer.Visible := False;
  pnlOrder := outer;
  f := MakePanel(outer, alClient, 0, clrPanel);
  { kerangka bisa dipindah: tarik judul / area kosong panel dengan mouse }
  f.OnMouseDown := OnOrdDrag;
  f.Cursor := crSizeAll;

  lblOrdTitle := MakeLabel(f, 'ORDER MT5', 8, 6, clrYellow, 10, True);
  lblOrdTitle.OnMouseDown := OnOrdDrag;
  lblOrdTitle.Cursor := crSizeAll;
  with MakeBtn(f, 'X', 278, 4, 26, 22, OnOpenBtn) do
  begin
    Bg := clrRedDim; Fg := clWhite; Bold := True;
  end;

  { BELI / JUAL }
  btnOrdBuy := MakeBtn(f, 'BELI', 6, 30, 146, 40, OnOrdSide, 1);
  btnOrdBuy.BgDown := clrGreen; btnOrdBuy.FgDown := clWhite; btnOrdBuy.Bg := clrGreenDim; btnOrdBuy.Fg := clWhite;
  btnOrdSell := MakeBtn(f, 'JUAL', 158, 30, 146, 40, OnOrdSide, -1);
  btnOrdSell.BgDown := clrRed; btnOrdSell.FgDown := clWhite; btnOrdSell.Bg := clrRedDim; btnOrdSell.Fg := clWhite;

  { bar persentase pembelian / penjualan }
  pbSent := TPaintBox.Create(Self);
  pbSent.Parent := f;
  pbSent.SetBounds(6, 76, 298, 34);
  pbSent.OnPaint := OnSentPaint;

  { beli otomatis (harga pasar) / pending }
  btnOrdMkt := MakeBtn(f, 'OTOMATIS (harga pasar)', 6, 116, 146, 26, OnOrdMode, 0);
  btnOrdMkt.BgDown := clrBlue; btnOrdMkt.FgDown := clWhite;
  btnOrdPend := MakeBtn(f, 'PENDING', 158, 116, 146, 26, OnOrdMode, 1);
  btnOrdPend.BgDown := clrBlue; btnOrdPend.FgDown := clWhite;

  { harga pending: geser naik / turun }
  MakeLabel(f, 'Harga', 8, 154, clrMuted, 8, True);
  MakeBtn(f, '-', 56, 150, 28, 24, OnPendStep, -1);
  edPend := TEdit.Create(Self);
  edPend.Parent := f;
  edPend.SetBounds(88, 150, 104, 24);
  edPend.Color := clrPanel2; edPend.Font.Color := clrYellow; edPend.Font.Style := [fsBold];
  edPend.OnChange := OnPendEdit;
  MakeBtn(f, '+', 196, 150, 28, 24, OnPendStep, 1);
  tbPend := TTrackBar.Create(Self);
  tbPend.Parent := f;
  tbPend.SetBounds(2, 178, 306, 28);
  tbPend.Min := -500; tbPend.Max := 500; tbPend.Position := 0;
  tbPend.Frequency := 100;
  tbPend.OnChange := OnPendTrack;
  lblPendInfo := MakeLabel(f, '', 8, 206, clrMuted, 8, True);

  { lot }
  MakeLabel(f, 'Lot', 8, 232, clrMuted, 8, True);
  MakeBtn(f, '-', 56, 228, 28, 24, OnOrdLotStep, -1);
  cbOrdLot := TComboBox.Create(Self);
  cbOrdLot.Parent := f;
  cbOrdLot.Style := csDropDown;
  cbOrdLot.SetBounds(88, 228, 104, 22);
  cbOrdLot.Color := clrPanel2; cbOrdLot.Font.Color := clrYellow; cbOrdLot.Font.Style := [fsBold];
  cbOrdLot.Items.CommaText := '0.01,0.02,0.03,0.05,0.10,0.20,0.30,0.50,1.00';
  cbOrdLot.Text := '0.01';
  cbOrdLot.OnChange := OnPendEdit;
  MakeBtn(f, '+', 196, 228, 28, 24, OnOrdLotStep, 1);

  { eksekusi }
  btnOrdExec := MakeBtn(f, 'EKSEKUSI', 6, 262, 298, 38, OnOrdExec);
  btnOrdExec.Bold := True;
  lblOrdRes := MakeLabel(f, 'Order dikirim ke MT5 hanya saat Anda klik EKSEKUSI.', 8, 306, clrMuted, 7);
  lblOrdRes.AutoSize := False;
  lblOrdRes.WordWrap := True;
  lblOrdRes.SetBounds(8, 306, 296, 30);

  { pesan untuk Fernanda + tombol tampil / sembunyikan }
  lblOrdMsg := MakeLabel(f, 'Pesan : Kalau Capek Fernanda Istirahat sekarang, Ngopi dulu.', 8, 338, RGB(255, 145, 0), 8, True);
  lblOrdMsg.AutoSize := False;
  lblOrdMsg.WordWrap := True;
  lblOrdMsg.SetBounds(8, 338, 214, 28);
  btnOrdMsg := MakeBtn(f, 'Sembunyikan', 226, 340, 64, 22, OnOrdMsg);
  btnOrdMsg.FontSize := 7;

  { simpan posisi & ukuran font dasar setiap kontrol untuk diskalakan saat panel diperbesar }
  pnlOrdIn := f;
  FOrdScale := 1;
  FOrdCtl := TList.Create;
  SetLength(FOrdBase, f.ControlCount);
  SetLength(FOrdFont, f.ControlCount);
  for i := 0 to f.ControlCount - 1 do
  begin
    FOrdCtl.Add(f.Controls[i]);
    FOrdBase[i] := f.Controls[i].BoundsRect;
    if f.Controls[i] is TFlatBtn then FOrdFont[i] := TFlatBtn(f.Controls[i]).FontSize
    else if f.Controls[i] is TLabel then FOrdFont[i] := TLabel(f.Controls[i]).Font.Size
    else if f.Controls[i] is TEdit then FOrdFont[i] := TEdit(f.Controls[i]).Font.Size
    else if f.Controls[i] is TComboBox then FOrdFont[i] := TComboBox(f.Controls[i]).Font.Size
    else FOrdFont[i] := 0;
  end;
  pbGrip := TPaintBox.Create(Self);
  pbGrip.Parent := f;
  pbGrip.SetBounds(f.ClientWidth - 16, f.ClientHeight - 16, 16, 16);
  pbGrip.Cursor := crSizeNWSE;
  pbGrip.OnPaint := OnGripPaint;
  pbGrip.OnMouseDown := OnGripDown;
  pbGrip.OnMouseMove := OnGripMove;
  OnOrdMode(btnOrdMkt);
end;

procedure TMainForm.LayoutOrderPanel;
var i, fsz: Integer; sx, sy, s: Double; r: TRect; c: TControl;
begin
  sx := pnlOrdIn.ClientWidth / 310;
  sy := pnlOrdIn.ClientHeight / 370;
  s := Min(sx, sy);
  FOrdScale := s;
  for i := 0 to FOrdCtl.Count - 1 do
  begin
    c := TControl(FOrdCtl[i]);
    r := FOrdBase[i];
    c.SetBounds(Round(r.Left * sx), Round(r.Top * sy), Round((r.Right - r.Left) * sx), Round((r.Bottom - r.Top) * sy));
    fsz := Round(FOrdFont[i] * s);
    if FOrdFont[i] > 0 then
    begin
      if c is TFlatBtn then begin TFlatBtn(c).FontSize := fsz; c.Invalidate; end
      else if c is TLabel then TLabel(c).Font.Size := fsz
      else if c is TEdit then TEdit(c).Font.Size := fsz
      else if c is TComboBox then TComboBox(c).Font.Size := fsz;
    end;
  end;
  pbGrip.SetBounds(pnlOrdIn.ClientWidth - 16, pnlOrdIn.ClientHeight - 16, 16, 16);
  pbSent.Invalidate;
end;

procedure TMainForm.OnOrdMsg(Sender: TObject);
begin
  lblOrdMsg.Visible := not lblOrdMsg.Visible;
  btnOrdMsg.Caption := Sx(lblOrdMsg.Visible, 'Sembunyikan', 'Tampilkan');
end;

procedure TMainForm.OnGripPaint(Sender: TObject);
var i: Integer;
begin
  with pbGrip.Canvas do
  begin
    Pen.Color := clrYellow;
    for i := 0 to 2 do
    begin
      MoveTo(15, 4 + i * 4); LineTo(4 + i * 4, 15);
    end;
  end;
end;

procedure TMainForm.OnGripDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  GetCursorPos(FGripPt);
  FGripW := pnlOrder.Width;
  FGripH := pnlOrder.Height;
end;

procedure TMainForm.OnGripMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var pt: TPoint; w, h: Integer;
begin
  if not (ssLeft in Shift) then Exit;
  GetCursorPos(pt);
  { minimal ukuran awal, maksimal sampai tepi area grafik }
  w := Max(312, Min(FGripW + pt.X - FGripPt.X, pnlCenter.ClientWidth - pnlOrder.Left));
  h := Max(372, Min(FGripH + pt.Y - FGripPt.Y, pnlCenter.ClientHeight - pnlOrder.Top));
  if (w = pnlOrder.Width) and (h = pnlOrder.Height) then Exit;
  pnlOrder.SetBounds(pnlOrder.Left, pnlOrder.Top, w, h);
  LayoutOrderPanel;
end;

{ harga acuan: MT5 bila terhubung (ask untuk beli, bid untuk jual), selain itu harga grafik }
function TMainForm.OrdPrice: Double;
var n: Integer;
begin
  if FMT5Bid > 0 then
  begin
    if FOrdSide > 0 then Result := FMT5Ask else Result := FMT5Bid;
  end
  else
  begin
    n := Length(FCandles);
    if n > 0 then Result := FCandles[n - 1].C else Result := 0;
  end;
end;

procedure TMainForm.UpdateOrderPanel;
var px, pp, ask, bid: Double; lot: Double; kind: string; d, n: Integer;
begin
  d := 2;
  if FMT5Bid > 0 then begin bid := FMT5Bid; ask := FMT5Ask; end
  else begin bid := OrdPrice; ask := bid; end;
  btnOpen.Caption := 'OPEN  ' + Sx(bid > 0, FmtP(bid, d), '');
  if not (pnlOrder.Visible and FOrdPending) and (Chart.PendPrice <> 0) then
  begin
    Chart.PendPrice := 0;
    Chart.Invalidate;
  end;
  if not pnlOrder.Visible then Exit;
  lblOrdTitle.Caption := 'ORDER MT5  ' + Sx(FMT5Sym <> '', FMT5Sym, '(belum terhubung)') +
    Sx(FMT5Alive and FMT5Old, '  EA LAMA!', '');
  lblOrdTitle.Font.Color := Cx(FMT5Alive and FMT5Old, clrRed, clrYellow);
  btnOrdBuy.Caption := 'BELI   ' + Sx(ask > 0, FmtP(ask, d), '');
  btnOrdSell.Caption := 'JUAL   ' + Sx(bid > 0, FmtP(bid, d), '');
  btnOrdBuy.Down := FOrdSide > 0;
  btnOrdSell.Down := FOrdSide < 0;
  btnOrdMkt.Down := not FOrdPending;
  btnOrdPend.Down := FOrdPending;
  edPend.Enabled := FOrdPending;
  tbPend.Enabled := FOrdPending;
  lot := PF(StringReplace(cbOrdLot.Text, ',', '.', []));
  px := OrdPrice;
  if FOrdPending then
  begin
    pp := PF(StringReplace(edPend.Text, ',', '.', []));
    if FOrdSide > 0 then kind := Sx(pp < ask, 'BUY LIMIT', 'BUY STOP')
    else kind := Sx(pp > bid, 'SELL LIMIT', 'SELL STOP');
    lblPendInfo.Caption := Format('%s  -  %.0f pips %s harga sekarang (%s)', [kind, Abs(pp - px) / 0.1,
      Sx(pp < px, 'di bawah', 'di atas'), FmtP(px, d)]);
    lblPendInfo.Font.Color := DirCol(FOrdSide);
    btnOrdExec.Caption := Format('EKSEKUSI %s %s @ %s', [kind, FormatFloat('0.00', lot), FmtP(pp, d)]);
    { garis hijau di grafik ikut harga pending. Grafik memakai harga Binance, jadi garis
      digambar pada jarak yang sama dari harga grafik seperti jarak harga pending dari harga MT5 }
    n := Length(FCandles);
    if (pp > 0) and (n > 0) then
    begin
      if FMT5Bid > 0 then Chart.PendPrice := FCandles[n - 1].C + (pp - px)
      else Chart.PendPrice := pp;
      Chart.PendLbl := Format('%s %s  @ %s', [kind, FormatFloat('0.00', lot), FmtP(pp, d)]) +
        Sx(FMT5Bid > 0, '  (MT5)', '');
    end
    else Chart.PendPrice := 0;
    Chart.Invalidate;
  end
  else
  begin
    lblPendInfo.Caption := 'Harga pasar: langsung dieksekusi di harga saat ini';
    lblPendInfo.Font.Color := clrMuted;
    btnOrdExec.Caption := Format('EKSEKUSI %s %s  (harga pasar)', [Sx(FOrdSide > 0, 'BELI', 'JUAL'), FormatFloat('0.00', lot)]);
  end;
  btnOrdExec.Bg := Cx(FOrdSide > 0, clrGreen, clrRed);
  btnOrdExec.Fg := clWhite;
  btnOrdExec.Invalidate;
  pbSent.Invalidate;
end;

procedure TMainForm.OnOrdDrag(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then Exit;
  ReleaseCapture;
  SendMessage(pnlOrder.Handle, WM_SYSCOMMAND, $F012, 0);   { SC_DRAGMOVE }
  { jaga agar tetap terlihat di area grafik }
  pnlOrder.Left := Max(0, Min(pnlOrder.Left, pnlCenter.ClientWidth - 60));
  pnlOrder.Top := Max(0, Min(pnlOrder.Top, pnlCenter.ClientHeight - 30));
  FOrdMoved := True;
end;

procedure TMainForm.OnOpenBtn(Sender: TObject);
var pt: TPoint;
begin
  pnlOrder.Visible := not pnlOrder.Visible;
  btnOpen.Down := pnlOrder.Visible;
  if pnlOrder.Visible then
  begin
    { pertama kali tepat di bawah tombol OPEN; setelah digeser, tetap di posisi pilihan pengguna }
    if not FOrdMoved then
    begin
      pt := pnlCenter.ScreenToClient(btnOpen.ClientToScreen(Point(0, 0)));
      pnlOrder.Left := Max(0, Min(pt.X + btnOpen.Width - pnlOrder.Width, pnlCenter.ClientWidth - pnlOrder.Width));
      pnlOrder.Top := 4;
    end;
    pnlOrder.BringToFront;
    if PF(edPend.Text) <= 0 then OnOrdMode(nil);
    UpdateOrderPanel;
  end;
end;

procedure TMainForm.OnOrdSide(Sender: TObject);
begin
  FOrdSide := TFlatBtn(Sender).Tag;
  UpdateOrderPanel;
end;

procedure TMainForm.OnOrdMode(Sender: TObject);
begin
  if Sender <> nil then FOrdPending := TFlatBtn(Sender).Tag = 1;
  { harga pending mulai dari harga saat ini, lalu digeser naik / turun }
  FPendBase := OrdPrice;
  FPendSync := True;
  tbPend.Position := 0;
  edPend.Text := FormatFloat('0.00', FPendBase);
  FPendSync := False;
  UpdateOrderPanel;
end;

procedure TMainForm.OnPendTrack(Sender: TObject);
begin
  if FPendSync then Exit;
  FPendSync := True;
  edPend.Text := FormatFloat('0.00', FPendBase + tbPend.Position * 0.1);
  FPendSync := False;
  UpdateOrderPanel;
end;

procedure TMainForm.OnPendStep(Sender: TObject);
begin
  if not FOrdPending then Exit;
  edPend.Text := FormatFloat('0.00', PF(StringReplace(edPend.Text, ',', '.', [])) + TFlatBtn(Sender).Tag * 0.1);
end;

procedure TMainForm.OnPendEdit(Sender: TObject);
var p: Integer;
begin
  if (Sender = edPend) and (not FPendSync) and (FPendBase > 0) then
  begin
    p := Round((PF(StringReplace(edPend.Text, ',', '.', [])) - FPendBase) / 0.1);
    FPendSync := True;
    tbPend.Position := Max(tbPend.Min, Min(tbPend.Max, p));
    FPendSync := False;
  end;
  UpdateOrderPanel;
end;

procedure TMainForm.OnOrdLotStep(Sender: TObject);
var lot: Double;
begin
  lot := PF(StringReplace(cbOrdLot.Text, ',', '.', [])) + TFlatBtn(Sender).Tag * 0.01;
  if lot < 0.01 then lot := 0.01;
  cbOrdLot.Text := FormatFloat('0.00', lot);
  UpdateOrderPanel;
end;

{ bar persentase pembelian / penjualan: volume candle naik vs turun (50 candle terakhir) }
procedure TMainForm.OnSentPaint(Sender: TObject);
var cv: TCanvas; i, n, w, bw, bh: Integer; vb, vs, pb: Double;
begin
  cv := pbSent.Canvas;
  w := pbSent.Width;
  bh := Round(pbSent.Height * 0.53);
  cv.Brush.Color := clrPanel;
  cv.FillRect(pbSent.ClientRect);
  n := Length(FCandles);
  vb := 0; vs := 0;
  for i := Max(0, n - 50) to n - 1 do
    if FCandles[i].C >= FCandles[i].O then vb := vb + FCandles[i].V else vs := vs + FCandles[i].V;
  if vb + vs > 0 then pb := vb / (vb + vs) else pb := 0.5;
  bw := Round(w * pb);
  cv.Brush.Color := clrGreen;
  cv.FillRect(Rect(0, 0, bw, bh));
  cv.Brush.Color := clrRed;
  cv.FillRect(Rect(bw, 0, w, bh));
  cv.Brush.Style := bsClear;
  cv.Font.Name := 'Segoe UI'; cv.Font.Size := Round(8 * FOrdScale); cv.Font.Style := [fsBold]; cv.Font.Color := clWhite;
  cv.TextOut(4, (bh - cv.TextHeight('B')) div 2, Format('Beli %.0f%%', [pb * 100]));
  cv.TextOut(w - cv.TextWidth(Format('Jual %.0f%%', [(1 - pb) * 100])) - 4, (bh - cv.TextHeight('J')) div 2,
    Format('Jual %.0f%%', [(1 - pb) * 100]));
  cv.Font.Style := []; cv.Font.Size := Round(7 * FOrdScale); cv.Font.Color := clrMuted;
  cv.TextOut(0, bh + 2, 'Tekanan beli / jual: volume 50 candle ' + TFLabels[FTF] + ' terakhir');
  cv.Brush.Style := bsSolid;
end;

procedure TMainForm.OnOrdExec(Sender: TObject);
var lot, pp: Double; side, kind, msg, id: string;
begin
  if not FMT5Alive then
  begin
    MessageDlg('Belom terhubung lagi ngambek Ho' + #13#10#13#10 +
      'Order tidak bisa dikirim. Buka MT5 dan pasang EA RecognitoBridge di chart.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if FMT5Old then
  begin
    MessageDlg('EA RecognitoBridge di MT5 masih versi LAMA dan belum bisa menerima order.' + #13#10#13#10 +
      'Di MT5: lepas EA dari chart (klik kanan chart > Expert Advisors > Remove),' + #13#10 +
      'lalu seret lagi RecognitoBridge dari Navigator ke chart.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if FOrdID <> '' then
  begin
    MessageDlg('Order sebelumnya masih menunggu jawaban MT5.', mtInformation, [mbOK], 0);
    Exit;
  end;
  lot := PF(StringReplace(cbOrdLot.Text, ',', '.', []));
  if lot < 0.01 then
  begin
    MessageDlg('Lot minimal 0.01.', mtWarning, [mbOK], 0);
    Exit;
  end;
  side := Sx(FOrdSide > 0, 'BUY', 'SELL');
  pp := 0;
  if FOrdPending then
  begin
    pp := PF(StringReplace(edPend.Text, ',', '.', []));
    if pp <= 0 then
    begin
      MessageDlg('Isi harga pending.', mtWarning, [mbOK], 0);
      Exit;
    end;
    if FOrdSide > 0 then kind := Sx(pp < FMT5Ask, 'BUY LIMIT', 'BUY STOP')
    else kind := Sx(pp > FMT5Bid, 'SELL LIMIT', 'SELL STOP');
    msg := Format('%s %s %s @ %s', [kind, FormatFloat('0.00', lot), FMT5Sym, FmtP(pp, 2)]);
  end
  else
    msg := Format('%s %s %s harga pasar (sekarang %s)', [Sx(FOrdSide > 0, 'BELI', 'JUAL'), FormatFloat('0.00', lot),
      FMT5Sym, FmtP(OrdPrice, 2)]);
  if MessageDlg('Kirim order NYATA ke MT5?' + #13#10#13#10 + msg + #13#10#13#10 +
    'Tanpa SL / TP. Trading berisiko.', mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not MT5WriteOrder(side, Sx(FOrdPending, 'PENDING', 'MARKET'), lot, pp, id) then
  begin
    lblOrdRes.Caption := 'Gagal menulis order ke folder MT5.';
    lblOrdRes.Font.Color := clrRed;
    Exit;
  end;
  FOrdID := id;
  FOrdAt := Now;
  lblOrdRes.Caption := 'Mengirim ke MT5: ' + msg + ' ...';
  lblOrdRes.Font.Color := clrYellow;
  AddLog('Order pengguna dikirim ke MT5: ' + msg, clrYellow);
end;

procedure TMainForm.OnMT5Auto(Sender: TObject);
begin
  { aplikasi hanya bisa MENGHENTIKAN order robot; mengaktifkan hanya oleh pengguna di chart MT5 }
  if FMT5Auto then
  begin
    if MessageDlg('Hentikan order robot di MT5?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
    FMT5Auto := False;
    if MT5WriteCmd(False, False, LotOf(cbLotBuy), LotOf(cbLotSell)) then
      AddLog('Perintah ke MT5: order robot DIHENTIKAN', clrYellow);
  end
  else
    MessageDlg('Order robot sedang MATI.' + #13#10#13#10 +
      'Untuk mengaktifkan, klik tombol AKTIFKAN ORDER di chart MT5' + #13#10 +
      '(tempat EA RecognitoBridge dipasang), lalu pilih Yes.' + #13#10#13#10 +
      'Robot tidak pernah aktif sendiri: selalu MATI saat EA dipasang.', mtInformation, [mbOK], 0);
end;

procedure TMainForm.OnMT5Close(Sender: TObject);
begin
  if MessageDlg('Tutup SEMUA posisi yang dibuka EA Recognito di MT5 sekarang?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if MT5WriteCmd(FMT5Auto, True, LotOf(cbLotBuy), LotOf(cbLotSell)) then AddLog('Perintah ke MT5: tutup semua posisi', clrYellow);
end;

procedure TMainForm.OnMT5Install(Sender: TObject);
var dirs: TStringList; n: Integer; own: string;
begin
  own := ExtractFilePath(ParamStr(0)) + 'RecognitoBridge.mq5';
  MT5ExtractEA(own);
  dirs := TStringList.Create;
  try
    n := MT5InstallEA(dirs);
    if n > 0 then
    begin
      REL(reMT5, Format('EA dipasang ke %d terminal MT5:', [n]), clrGreen, True);
      REL(reMT5, dirs.Text, clrText);
      ShowMessage(Format('EA RecognitoBridge berhasil dipasang ke %d terminal MT5.', [n]) + #13#10#13#10 +
        'Di MT5: Navigator > Expert Advisors > klik kanan > Refresh.' + #13#10 +
        'Bila belum muncul: buka MetaEditor (F4), buka RecognitoBridge.mq5, tekan F7.' + #13#10 +
        'Lalu seret EA ke chart XAUUSD dan izinkan Algo Trading.');
    end
    else
      ShowMessage('Folder data MT5 tidak ditemukan di komputer ini.' + #13#10#13#10 +
        'Pastikan MT5 Exness sudah terpasang dan pernah dibuka sekali.' + #13#10 +
        'File EA sudah disimpan di:' + #13#10 + own + #13#10#13#10 +
        'Di MT5 pilih File > Open Data Folder > MQL5 > Experts, lalu salin file itu ke sana.');
  finally
    dirs.Free;
  end;
end;

function TMainForm.LotOf(C: TComboBox): Double;
begin
  Result := PF(C.Text);
  if Result <= 0 then Result := 0.01;
end;

procedure TMainForm.OnLotChange(Sender: TObject);
begin
  FLotSynced := True;
  if MT5WriteCmd(FMT5Auto, False, LotOf(cbLotBuy), LotOf(cbLotSell)) then
    AddLog(Format('Lot robot MT5: BUY %s  |  SELL %s', [cbLotBuy.Text, cbLotSell.Text]), clrYellow);
end;

procedure TMainForm.OnStopFer(Sender: TObject);
begin
  FMT5Auto := False;
  btnMT5Auto.Down := False;
  btnMT5Auto.Caption := 'ORDER ROBOT: MATI';
  if MT5WriteCmd(False, False, LotOf(cbLotBuy), LotOf(cbLotSell)) then
    Alarm('STOP FER: robot MT5 dihentikan - tidak membuka posisi baru.', 0);
  if MessageDlg('Robot sudah dihentikan.' + #13#10#13#10 + 'Tutup juga SEMUA posisi milik robot sekarang?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    MT5WriteCmd(False, True, LotOf(cbLotBuy), LotOf(cbLotSell));
    AddLog('STOP FER: perintah tutup semua posisi dikirim ke MT5', clrYellow);
  end;
end;

procedure TMainForm.OnMT5Folder(Sender: TObject);
var own: string;
begin
  own := ExtractFilePath(ParamStr(0)) + 'RecognitoBridge.mq5';
  MT5ExtractEA(own);
  ShellExecute(Handle, 'open', 'explorer.exe', PChar('/select,"' + own + '"'), nil, SW_SHOWNORMAL);
end;

procedure TMainForm.BuildCalc(P: TPanel);
var f: TPanel; y: Integer;

  function Row(const Cap, Def: string): TEdit;
  begin
    MakeLabel(f, Cap, 6, y + 3, clrMuted, 9);
    Result := TEdit.Create(Self);
    Result.Parent := f;
    Result.SetBounds(210, y, 200, 22);
    Result.Color := clrPanel2;
    Result.Font.Color := clrText;
    Result.Font.Name := 'Segoe UI';
    Result.Text := Def;
    Inc(y, 28);
  end;

begin
  f := MakePanel(P, alTop, 300, clrPanel);
  MakeLabel(f, 'KALKULATOR XAU (1 lot = 100 oz, 1 pip = 0.10)', 6, 0, clrYellow, 10, True);
  y := 26;

  { saldo: pilih 100..1000 atau ketik langsung }
  MakeLabel(f, 'Saldo / modal (USD) - pilih / ketik', 6, y + 3, clrMuted, 9);
  edBal := TComboBox.Create(Self);
  edBal.Parent := f;
  edBal.Style := csDropDown;
  edBal.SetBounds(210, y, 200, 22);
  edBal.Color := clrPanel2;
  edBal.Font.Color := clrText;
  edBal.Font.Name := 'Segoe UI';
  edBal.DropDownCount := 10;
  edBal.Items.CommaText := '100,200,300,400,500,600,700,800,900,1000';
  edBal.Text := '1000';
  edBal.OnChange := OnCalcBtn;
  Inc(y, 28);

  { lot: standar 0.01, tombol - / + untuk menambah per 0.01 }
  MakeLabel(f, 'Lot (standar 0.01)', 6, y + 3, clrMuted, 9);
  MakeBtn(f, '-', 210, y, 30, 22, OnLotStep, -1);
  edLot := TEdit.Create(Self);
  edLot.Parent := f;
  edLot.SetBounds(244, y, 86, 22);
  edLot.Color := clrPanel2;
  edLot.Font.Color := clrYellow;
  edLot.Font.Name := 'Segoe UI';
  edLot.Font.Style := [fsBold];
  edLot.Text := '0.01';
  with MakeBtn(f, '+', 334, y, 30, 22, OnLotStep, 1) do
  begin
    Bg := clrGreenDim; Fg := clWhite; Bold := True;
  end;
  MakeBtn(f, 'Rekom.', 368, y, 42, 22, OnLotRek);
  Inc(y, 28);

  edRisk := Row('Risiko per trade (%)', '1');
  edEntry := Row('Harga entry', '');
  edSL := Row('Stop Loss (harga, boleh kosong)', '');
  edTP := Row('Take Profit (harga)', '');
  edLev := Row('Leverage (1 : x)', '500');
  btnBuyCalc := MakeBtn(f, 'BUY', 6, y + 2, 64, 28, OnCalcDir, 1);
  btnBuyCalc.BgDown := clrGreen; btnBuyCalc.FgDown := clWhite;
  btnBuyCalc.Down := True;
  btnSellCalc := MakeBtn(f, 'SELL', 74, y + 2, 64, 28, OnCalcDir, -1);
  btnSellCalc.BgDown := clrRed; btnSellCalc.FgDown := clWhite;
  MakeBtn(f, 'Harga kini', 146, y + 2, 76, 28, OnCalcNow);
  MakeBtn(f, 'Dari sinyal', 226, y + 2, 82, 28, OnCalcSig);
  with MakeBtn(f, 'HITUNG', 312, y + 2, 98, 28, OnCalcBtn) do
  begin
    Bg := clrYellow; Fg := clrBg; Bold := True;
  end;
  reCalc := NewRE(P, False);
end;

{ ---------------- Tab Edukasi: Edukasi / Running Text ---------------- }

procedure TMainForm.BuildEduTab(P: TPanel);
var top, f: TPanel;
begin
  top := MakePanel(P, alTop, 34, clrPanel);
  MakeLabel(top, 'Tampilkan:', 4, 9, clrMuted, 9, True);
  cbEduMode := TComboBox.Create(Self);
  cbEduMode.Parent := top;
  cbEduMode.Style := csDropDownList;
  cbEduMode.SetBounds(80, 5, 200, 22);
  cbEduMode.Color := clrPanel2; cbEduMode.Font.Color := clrYellow; cbEduMode.Font.Style := [fsBold];
  cbEduMode.Items.CommaText := '"1. Edukasi","2. Running Text"';
  cbEduMode.ItemIndex := 0;
  cbEduMode.OnChange := OnEduMode;

  reEdu := NewRE(P, False);

  { editor running text }
  pnlEduRun := MakePanel(P, alClient, 0, clrPanel);
  pnlEduRun.Visible := False;
  f := MakePanel(pnlEduRun, alTop, 58, clrPanel);
  MakeLabel(f, 'RUNNING TEXT', 4, 2, clrYellow, 11, True);
  MakeLabel(f, 'Tulis teks di bawah: langsung berjalan pelan di bawah grafik. Kosong = tidak tampil.', 4, 24, clrMuted, 8);
  MakeLabel(f, 'Beberapa baris digabung jadi satu jalur.', 4, 38, clrMuted, 7);
  memRun := TMemo.Create(Self);
  memRun.Parent := pnlEduRun;
  memRun.Align := alTop;
  memRun.Height := 140;
  memRun.Color := clrPanel2;
  memRun.Font.Name := 'Segoe UI'; memRun.Font.Size := 10; memRun.Font.Color := clrText;
  memRun.ScrollBars := ssVertical;
  memRun.OnChange := OnRunChange;
  f := MakePanel(pnlEduRun, alTop, 40, clrPanel);
  f.Top := 1000;
  MakeLabel(f, 'Kecepatan:', 4, 14, clrMuted, 9, True);
  cbRunSpeed := TComboBox.Create(Self);
  cbRunSpeed.Parent := f;
  cbRunSpeed.Style := csDropDownList;
  cbRunSpeed.SetBounds(80, 10, 110, 22);
  cbRunSpeed.Color := clrPanel2; cbRunSpeed.Font.Color := clrText;
  cbRunSpeed.Items.CommaText := 'Pelan,Sedang,Cepat';
  cbRunSpeed.ItemIndex := 0;
  with MakeBtn(f, 'HAPUS TEKS', 200, 8, 100, 26, OnRunClear) do
  begin
    Bg := clrRedDim; Fg := clWhite; Bold := True;
  end;
  { tampil / sembunyikan teks berjalan tanpa menghapus teksnya }
  btnRunShow := MakeBtn(f, 'SEMBUNYIKAN', 306, 8, 110, 26, OnRunShow);
  btnRunShow.Bg := clrBlue; btnRunShow.Fg := clWhite; btnRunShow.Bold := True;
end;

procedure TMainForm.OnRunShow(Sender: TObject);
begin
  FRunHidden := not FRunHidden;
  try
    with TStringList.Create do
    try
      Values['TAMPIL'] := Sx(FRunHidden, '0', '1');
      SaveToFile(ChangeFileExt(RunFile, '.ini'));
    finally
      Free;
    end;
  except
  end;
  FRunText := #0;   { paksa hitung ulang }
  UpdateRunText;
end;

procedure TMainForm.OnEduMode(Sender: TObject);
begin
  reEdu.Visible := cbEduMode.ItemIndex = 0;
  pnlEduRun.Visible := cbEduMode.ItemIndex = 1;
  if pnlEduRun.Visible and memRun.CanFocus then memRun.SetFocus;
end;

function TMainForm.RunFile: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'runningtext.txt';
end;

procedure TMainForm.OnRunChange(Sender: TObject);
begin
  try
    memRun.Lines.SaveToFile(RunFile);
  except
  end;
  UpdateRunText;
end;

procedure TMainForm.OnRunClear(Sender: TObject);
begin
  memRun.Clear;
end;

{ gabung semua baris jadi satu jalur; kosong = bar disembunyikan }
procedure TMainForm.UpdateRunText;
var i: Integer; s, t: string;
begin
  s := '';
  for i := 0 to memRun.Lines.Count - 1 do
  begin
    t := Trim(memRun.Lines[i]);
    if t = '' then Continue;
    if s <> '' then s := s + '     ' + #149 + '     ';
    s := s + t;
  end;
  btnRunShow.Caption := Sx(FRunHidden, 'TAMPILKAN', 'SEMBUNYIKAN');
  btnRunShow.Bg := Cx(FRunHidden, clrGreenDim, clrBlue);
  btnRunShow.Invalidate;
  if s = FRunText then Exit;
  if (FRunText = '') or (FRunText = #0) then FRunX := pbRun.Width;   { mulai dari kanan }
  FRunText := s;
  { tampil hanya bila ada teks dan tidak disembunyikan }
  pnlRun.Visible := (s <> '') and not FRunHidden;
  tmRun.Enabled := pnlRun.Visible;
  pbRun.Invalidate;
end;

procedure TMainForm.OnRunTick(Sender: TObject);
const Step: array[0..2] of Integer = (1, 2, 4);
begin
  if not pnlRun.Visible then Exit;
  Dec(FRunX, Step[Max(0, cbRunSpeed.ItemIndex)]);
  pbRun.Invalidate;
end;

procedure TMainForm.OnRunPaint(Sender: TObject);
var cv: TCanvas; tw: Integer;
begin
  cv := pbRun.Canvas;
  cv.Brush.Color := RGB(16, 20, 30);
  cv.FillRect(pbRun.ClientRect);
  if FRunText = '' then Exit;
  cv.Font.Name := 'Segoe UI'; cv.Font.Size := 11; cv.Font.Style := [fsBold]; cv.Font.Color := clrYellow;
  tw := cv.TextWidth(FRunText);
  { setelah teks habis di kiri, mulai lagi dari kanan }
  if FRunX < -tw then FRunX := pbRun.Width;
  if FRunX > pbRun.Width then FRunX := pbRun.Width;
  cv.Brush.Style := bsClear;
  cv.TextOut(FRunX, (pbRun.Height - cv.TextHeight(FRunText)) div 2, FRunText);
  cv.Brush.Style := bsSolid;
end;

procedure TMainForm.BuildEdu;
var R: TRichEdit;
  procedure H(const S: string); begin REH(R, S); end;
  procedure S2(const S: string); begin REL(R, S, RGB(0, 188, 212), True); end;
  procedure B(const S: string); begin REL(R, '  ' + #149 + ' ' + S, clrText); end;
  procedure G(const S: string); begin REL(R, '  ' + #149 + ' ' + S, clrGreen); end;
  procedure Rd(const S: string); begin REL(R, '  ' + #149 + ' ' + S, clrRed); end;
  procedure W(const S: string); begin REL(R, '  ! ' + S, RGB(255, 145, 0), True); end;
begin
  R := reEdu;
  R.Lines.BeginUpdate;
  REL(R, 'PANDUAN LENGKAP MEMBACA GRAFIK & TRADING XAU', clrYellow, True, 12);

  H('1. DASAR GRAFIK');
  B('OHLC Data: harga Pembukaan (Open), Tertinggi (High), Terendah (Low), dan Penutupan (Close).');
  B('Volume: jumlah transaksi / kekuatan di balik pergerakan harga. Volume besar mengonfirmasi bahwa pergerakan harga tersebut valid.');
  B('Sumbu (Axes): sumbu vertikal = skala harga, sumbu horizontal = skala waktu (timeframe).');
  B('Timeframe: durasi setiap candle (1 menit, 1 jam, harian/1D, mingguan/1W). Timeframe besar (harian/mingguan) lebih akurat dibanding timeframe kecil.');
  S2('Cara pakai grafik di aplikasi ini:');
  B('Drag kiri/kanan = geser waktu. Scroll mouse = zoom kecil/besar. Shift+scroll = geser.');
  B('Drag pada sumbu harga (kanan) atas/bawah = perbesar/perkecil range harga. Ctrl+scroll = zoom harga.');
  B('Drag pada sumbu waktu (bawah) = rapat/renggang candle. Klik ganda = skala harga otomatis.');

  H('2. ARAH TREN');
  G('Uptrend (Tren Naik): puncak lebih tinggi (higher high) dan lembah lebih tinggi (higher low).');
  Rd('Downtrend (Tren Turun): puncak lebih rendah (lower high) dan lembah lebih rendah (lower low).');
  B('Sideways (Konsolidasi): harga mendatar di antara batas atas dan batas bawah.');

  H('3. LEVEL PENTING & POLA GRAFIK');
  G('Support: area harga bawah di mana tekanan beli cukup kuat menahan harga turun lebih dalam.');
  Rd('Resistance: area harga atas di mana tekanan jual cukup kuat menahan harga naik lebih tinggi.');
  B('S1, S2, S3 & R1, R2, R3 dihitung dari Pivot Point periode sebelumnya: P = (H + L + C) / 3.');
  B('Pola Pembalikan (Reversal): Head and Shoulders, Double Top, Double Bottom.');
  B('Pola Kelanjutan (Continuation): Triangle, Flag, Pennant.');

  H('4. KESALAHAN UMUM PEMULA');
  Rd('Mengabaikan volume: masuk pasar tanpa melihat besar kecilnya volume transaksi.');
  Rd('Hanya fokus timeframe pendek: terjebak grafik 1-5 menit tanpa melihat gambaran besar harian.');
  Rd('Melawan tren utama (counter-trend) tanpa alasan teknikal yang kuat.');
  Rd('Menganggap grafik memberi kepastian: grafik mengukur PROBABILITAS, bukan menjamin 100% profit. Selalu gunakan manajemen risiko.');

  H('5. POLA TRADING XAUUSD');
  S2('Double Bottom & Double Top');
  G('Double Bottom: potensi pembalikan bullish setelah tren turun, dua dasar sejajar di support.');
  Rd('Double Top: pembalikan bearish setelah tren naik, dua puncak sejajar di resistance.');
  B('Cara trading: entry setelah breakout neckline dengan volume tinggi. SL di bawah support / di atas resistance.');
  S2('Triangle');
  G('Ascending Triangle: resistance horizontal + support naik (bullish) - fokus BUY saat breakout.');
  Rd('Descending Triangle: support horizontal + resistance turun (bearish) - fokus SELL saat breakdown.');
  S2('Bullish & Bearish Flag / Pennant');
  B('Muncul saat tren kuat. Bullish flag = konsolidasi kecil dalam tren naik, bearish flag = dalam tren turun.');
  B('Cara trading: tunggu breakout dari flag searah tren utama. SL di luar area flag.');
  S2('Head and Shoulders');
  Rd('Head and Shoulders: pembalikan bearish, tiga puncak dengan puncak tengah tertinggi.');
  G('Inverse Head and Shoulders: pembalikan bullish, tiga lembah dengan lembah tengah terendah.');
  B('Cara trading: entry setelah break neckline + volume tinggi. SL di atas/di bawah pola.');
  S2('Hammer & Shooting Star');
  G('Hammer: sumbu bawah panjang, tekanan beli kuat (pembalikan bullish).');
  Rd('Shooting Star: sumbu atas panjang, tekanan jual kuat (pembalikan bearish).');
  B('Cara trading: entry setelah candle konfirmasi, target di resistance / support berikutnya.');

  H('6. KAMUS ARTI CANDLE (label di grafik)');
  G('Candle Hijau (Bullish): Close > Open, pembeli menang pada periode itu.');
  Rd('Candle Merah (Bearish): Close < Open, penjual menang pada periode itu.');
  B('Badan (body) panjang = dorongan kuat. Sumbu (wick/shadow) panjang = penolakan harga di area itu.');
  B('D  - Doji: open = close, pasar ragu, sering terjadi sebelum pembalikan. Tunggu konfirmasi.');
  G('DD - Dragonfly Doji: sumbu bawah panjang, harga bawah ditolak (bullish).');
  Rd('GD - Gravestone Doji: sumbu atas panjang, harga atas ditolak (bearish).');
  G('H  - Hammer: muncul di dasar, sumbu bawah >= 2x badan. Potensi naik.');
  G('IH - Inverted Hammer: di dasar, sumbu atas panjang. Pembeli mulai masuk.');
  Rd('HM - Hanging Man: bentuk hammer di puncak. Waspada turun.');
  Rd('SS - Shooting Star: di puncak, sumbu atas panjang. Potensi turun.');
  B('MB - Marubozu: badan penuh tanpa sumbu. Hijau = pembeli dominan, merah = penjual dominan.');
  B('Spinning Top: badan kecil, sumbu atas & bawah panjang. Pasar seimbang/ragu.');
  G('BuE - Bullish Engulfing: candle hijau menelan penuh candle merah sebelumnya. Sinyal naik kuat.');
  Rd('BeE - Bearish Engulfing: candle merah menelan penuh candle hijau sebelumnya. Sinyal turun kuat.');
  G('PL - Piercing Line: hijau menutup di atas separuh candle merah sebelumnya.');
  Rd('DCC - Dark Cloud Cover: merah menutup di bawah separuh candle hijau sebelumnya.');
  B('Harami: candle kecil di dalam badan candle besar sebelumnya - momentum melemah.');
  B('Tweezer Top / Bottom: dua candle dengan high / low sama - penolakan level kuat.');
  G('MS - Morning Star (3 candle): merah besar, candle kecil, hijau besar. Pembalikan naik.');
  Rd('ES - Evening Star (3 candle): hijau besar, candle kecil, merah besar. Pembalikan turun.');
  G('3WS - Three White Soldiers: tiga hijau beruntun, tren naik kuat.');
  Rd('3BC - Three Black Crows: tiga merah beruntun, tren turun kuat.');

  H('7. SMART MONEY CONCEPT (SMC)');
  B('BOS (Break of Structure): harga menembus swing high/low searah tren = tren BERLANJUT.');
  B('CHoCH (Change of Character): penembusan pertama berlawanan arah tren = tanda tren BERBALIK (label kuning di grafik).');
  B('FVG (Fair Value Gap): celah/imbalance 3 candle. Harga sering kembali mengisi FVG sebelum melanjutkan arah. Kotak hijau = FVG bullish (area buy), merah = FVG bearish (area sell).');
  B('Premium / Discount: di atas 50% range swing = premium (cari SELL), di bawah 50% = discount (cari BUY).');
  B('Strategi: tunggu CHoCH -> tunggu harga retrace ke FVG / order block -> entry -> SL di luar swing -> TP di likuiditas berikutnya.');

  H('8. MOVING AVERAGE & PERSILANGAN');
  REL(R, '  MA9 (kuning) = momentum sangat pendek', MAColors[0]);
  REL(R, '  MA25 (magenta) = tren pendek', MAColors[1]);
  REL(R, '  MA99 (cyan) = tren menengah', MAColors[2]);
  REL(R, '  MA200 (oranye) = tren besar, batas bull/bear market', MAColors[3]);
  REL(R, '  MA500 (biru) = tren jangka panjang', MAColors[4]);
  REL(R, '  MA700 (lime) = tren super panjang / support-resistance mayor', MAColors[5]);
  G('Golden Cross: MA cepat memotong ke ATAS MA lambat = sinyal NAIK.');
  Rd('Death Cross: MA cepat memotong ke BAWAH MA lambat = sinyal TURUN.');
  B('Persilangan pada MA besar (99/200, 200/500) jauh lebih kuat daripada MA kecil (9/25).');

  H('9. BOLLINGER BANDS (20, 2)');
  B('Harga menyentuh band atas = relatif mahal (overbought), band bawah = relatif murah (oversold).');
  B('Band menyempit (squeeze) = volatilitas rendah, biasanya diikuti breakout besar.');
  B('Dalam tren kuat harga bisa "berjalan" di sepanjang band - jangan langsung melawan.');

  H('10. SESI TRADING (perkiraan waktu WIB, berubah saat DST)');
  B('Sydney: 04:00 - 13:00 WIB (musim panas Australia 03:00 - 12:00).');
  B('Tokyo: 07:00 - 16:00 WIB.');
  B('London: 14:00 - 23:00 WIB (musim panas Eropa 13:00 - 22:00).');
  B('New York: 19:00 - 04:00 WIB (musim panas AS 20:00 - 05:00 lebih awal 1 jam).');
  W('Overlap London - New York = volatilitas XAUUSD paling tinggi.');
  B('Jadwal pasti dihitung otomatis di tab "Sesi & Berita" lengkap dengan alarm 5 menit sebelum pergantian.');

  H('11. TIPS & MANAJEMEN RISIKO');
  B('Gunakan indikator tambahan: kombinasikan pola dengan RSI atau MACD untuk validasi sinyal.');
  B('Perhatikan waktu: XAUUSD paling volatil pada sesi London dan New York.');
  B('Rasio risk:reward minimal 1:2 untuk setiap entry. Risiko per trade 1-2% saldo.');
  B('Hindari entry 15 menit sebelum & sesudah berita besar (FOMC, NFP, CPI).');
  B('Tambahkan jadwal berita sendiri di file events.txt (format: 2026-11-06 20:30;Judul;High).');
  W('Semua sinyal di aplikasi ini adalah alat bantu analisa, BUKAN jaminan profit.');
  R.SelStart := 0;
  R.Lines.EndUpdate;
end;

{ ---------------- Data ---------------- }

function TMainForm.PipSize: Double;
var n: Integer;
begin
  if FIsGold then Result := 0.1
  else
  begin
    n := Length(FCandles);
    if n > 0 then Result := FCandles[n - 1].C * 0.0001 else Result := 0.0001;
  end;
end;

function TMainForm.PriceDigits: Integer;
var n: Integer;
begin
  n := Length(FCandles);
  if n > 0 then Result := DigitsFor(FCandles[n - 1].C) else Result := 2;
end;

function TMainForm.KlineURLs(const TF: string; Limit: Integer): string;
var spot, fut: string;
begin
  if FIsGold then
  begin
    spot := Format('https://data-api.binance.vision/api/v3/klines?symbol=PAXGUSDT&interval=%s&limit=%d|' +
                   'https://api.binance.com/api/v3/klines?symbol=PAXGUSDT&interval=%s&limit=%d', [TF, Limit, TF, Limit]);
    fut := Format('https://fapi.binance.com/fapi/v1/klines?symbol=XAUUSDT&interval=%s&limit=%d', [TF, Limit]);
    if FFapiFail then Result := spot
    else Result := fut + '|' + spot;
  end
  else
    Result := Format('https://data-api.binance.vision/api/v3/klines?symbol=%s&interval=%s&limit=%d|' +
                     'https://api.binance.com/api/v3/klines?symbol=%s&interval=%s&limit=%d', [FSym, TF, Limit, FSym, TF, Limit]);
end;

procedure TMainForm.SelectSymbol(const Sym: string; Gold: Boolean);
var i: Integer;
begin
  FIsGold := Gold;
  OnCapClose(nil);
  if Gold then FSym := 'XAUUSDT' else FSym := Sym;
  FDispSym := FSym;
  btnGold.Down := Gold;
  SetLength(FCandles, 0);
  for i := 0 to 6 do begin SetLength(FMTF[i], 0); FMTFInfo[i].OK := False; end;
  Chart.C := nil;
  Chart.Title := FSym + '  ' + TFLabels[FTF];
  Chart.ResetView;
  lblSym.Caption := FSym;
  lblPrice.Caption := '...';
  LoadMain;
  LoadMTF;
end;

procedure TMainForm.LoadMain;
begin
  Inc(FSeq);
  lblStatus.Caption := 'Memuat ' + FSym + ' ' + TFLabels[FTF] + ' ...';
  TFetchThread.Create(KIND_MAIN, FSeq, [KlineURLs(TFNames[FTF], 1000)], FetchDone);
end;

procedure TMainForm.LoadLive;
begin
  if FBusyLive or (Length(FCandles) = 0) then Exit;
  FBusyLive := True;
  TFetchThread.Create(KIND_LIVE, FSeq, [KlineURLs(TFNames[FTF], 3)], FetchDone);
end;

procedure TMainForm.LoadMTF;
var u: array[0..6] of string; i: Integer;
begin
  if FBusyMTF then Exit;
  FBusyMTF := True;
  for i := 0 to 6 do u[i] := KlineURLs(TFNames[i], 300);
  TFetchThread.Create(KIND_MTF, FSeq, u, FetchDone);
end;

procedure TMainForm.LoadTickers;
begin
  if FBusyTick then Exit;
  FBusyTick := True;
  if FFapiFail then
    TFetchThread.Create(KIND_TICK, 0, ['https://data-api.binance.vision/api/v3/ticker/24hr|https://api.binance.com/api/v3/ticker/24hr'], FetchDone)
  else
    TFetchThread.Create(KIND_TICK, 0, ['https://data-api.binance.vision/api/v3/ticker/24hr|https://api.binance.com/api/v3/ticker/24hr',
      'https://fapi.binance.com/fapi/v1/ticker/24hr?symbol=XAUUSDT'], FetchDone);
end;

procedure TMainForm.LoadCalendar;
begin
  TFetchThread.Create(KIND_CAL, 0, ['https://nfs.faireconomy.media/ff_calendar_thisweek.json'], FetchDone);
end;

procedure TMainForm.FetchDone(T: TFetchThread);
var A, B: TCandles; i, j, n, k: Integer; tk: TTickers; ev: TEcoEvents; nowU, wMin, wMax: TDateTime;
    dup: Boolean;

  procedure NoteGoldSource(Alt: Integer);
  begin
    if not FIsGold then begin FSrc := 'Binance Spot ' + FSym; Exit; end;
    if (Alt = 0) and not FFapiFail then
    begin
      FSrc := 'Binance Futures XAUUSDT';
      FDispSym := 'XAUUSDT';
      FFapiFail := False;
    end
    else
    begin
      FSrc := 'Binance Spot PAXGUSDT (emas 1:1, proxy XAU)';
      FDispSym := 'XAUUSDT (PAXG)';
      if not FFapiFail then
      begin
        FFapiFail := True;
        FFapiRetry := Now + 15 / 1440;
      end;
    end;
  end;

begin
  case T.Kind of
    KIND_PROBE:
      begin
        if T.OKs[0] then
        begin
          if FFapiFail then AddLog('Binance Futures XAUUSDT tersedia - memakai harga XAUUSDT asli.', clrGreen);
          FFapiFail := False;
          if FIsGold then SelectSymbol('XAUUSDT', True);
        end
        else
        begin
          if FFapiRetry > Now + 0.5 then
            AddLog('Binance Futures tidak dapat diakses dari jaringan ini - XAU memakai PAXGUSDT (emas 1:1).', clrMuted);
          FFapiFail := True;
          FFapiRetry := Now + 15 / 1440;
        end;
      end;
    KIND_MAIN:
      begin
        if T.Seq <> FSeq then Exit;
        { data kadang datang basi (candle terakhir jauh di masa lalu): anggap gagal & muat ulang }
        if T.OKs[0] and ParseKlines(T.Results[0], A) and (Length(A) > 0) and
           (A[High(A)].T / 1000 < (NowUTC - 25569) * 86400 - 3 * TFSecs[FTF]) then
        begin
          AddLog('Data ' + FSym + ' dari Binance basi (candle terakhir lama) - memuat ulang.', RGB(255, 145, 0));
          FMainRetry := Now + 3 / 86400;
          Exit;
        end;
        if (not T.OKs[0]) or (not ParseKlines(T.Results[0], A)) then
        begin
          lblStatus.Caption := 'Gagal memuat data ' + FSym + '. Periksa koneksi internet. Mencoba lagi otomatis...';
          AddLog('Gagal memuat data ' + FSym + ', mencoba lagi dalam 3 detik.', clrRed);
          FMainRetry := Now + 3 / 86400;
          Exit;
        end;
        NoteGoldSource(T.UsedAlt[0]);
        FMainAlt := T.UsedAlt[0];
        FCandles := A;
        lblSym.Caption := FDispSym;
        Chart.Title := FDispSym + '  ' + TFLabels[FTF];
        Recompute(True);
        WriteNews;
      end;
    KIND_LIVE:
      begin
        FBusyLive := False;
        if (T.Seq <> FSeq) or (not T.OKs[0]) or (Length(FCandles) = 0) then Exit;
        if FIsGold and (T.UsedAlt[0] <> FMainAlt) then
        begin
          LoadMain;
          Exit;
        end;
        if not ParseKlines(T.Results[0], B) then Exit;
        n := Length(FCandles);
        for i := 0 to High(B) do
        begin
          if B[i].T = FCandles[n - 1].T then FCandles[n - 1] := B[i]
          else if B[i].T > FCandles[n - 1].T then
          begin
            SetLength(FCandles, n + 1);
            FCandles[n] := B[i];
            n := n + 1;
          end
          else
            for j := n - 2 downto Max(0, n - 4) do
              if FCandles[j].T = B[i].T then FCandles[j] := B[i];
        end;
        Recompute(False);
      end;
    KIND_MTF:
      begin
        FBusyMTF := False;
        if T.Seq <> FSeq then Exit;
        for i := 0 to 6 do
          if T.OKs[i] and ParseKlines(T.Results[i], A) then
          begin
            FMTF[i] := A;
            FMTFInfo[i] := AnalyzeTF(A, PipSize);
          end;
        ComputeSessRanges;
        WriteMTF;
        if Length(FCandles) > 0 then Recompute(True);
        pbSess.Invalidate;
      end;
    KIND_TICK:
      begin
        FBusyTick := False;
        if T.OKs[0] then
        begin
          ParseTickers(T.Results[0], tk);
          for i := 0 to High(tk) do
            with tk[i] do
            begin
              if Copy(Sym, Length(Sym) - 3, 4) = 'USDT' then Base := Copy(Sym, 1, Length(Sym) - 4);
              if (High > 0) and (Last >= High * 0.998) and (Chg > 0) then Status := 1
              else if (Low > 0) and (Last <= Low * 1.002) and (Chg < 0) then Status := -1;
              IsGold := (Base = 'PAXG') or (Base = 'XAUT');
            end;
          FTick := tk;
          Inc(FTickN);
          ApplyFilter;
        end;
        FHasGoldFut := False;
        if (T.URLs.Count > 1) and T.OKs[1] then
        begin
          ParseTickers(T.Results[1], tk);
          if Length(tk) > 0 then begin FGoldTick := tk[0]; FHasGoldFut := True; end;
        end
        else if T.URLs.Count > 1 then
        begin
          if not FFapiFail then begin FFapiFail := True; FFapiRetry := Now + 15 / 1440; end;
        end;
        if not FHasGoldFut then
          for i := 0 to High(FTick) do
            if FTick[i].Sym = 'PAXGUSDT' then begin FGoldTick := FTick[i]; Break; end;
        if FGoldTick.Last > 0 then
        begin
          lblGoldPrice.Caption := FmtP(FGoldTick.Last, 2);
          lblGoldChg.Caption := FormatFloat('+0.00;-0.00', FGoldTick.Chg) + '%';
          lblGoldChg.Font.Color := DirCol(Sign(FGoldTick.Chg));
          lblGoldPrice.Font.Color := DirCol(Sign(FGoldTick.Chg));
          if FHasGoldFut then lblGoldSrc.Caption := 'H ' + FmtP(FGoldTick.High, 2) + '  L ' + FmtP(FGoldTick.Low, 2) + '  ' + #149 + '  Binance Futures XAUUSDT'
          else lblGoldSrc.Caption := 'H ' + FmtP(FGoldTick.High, 2) + '  L ' + FmtP(FGoldTick.Low, 2) + '  ' + #149 + '  PAXGUSDT (emas 1:1, proxy XAU)';
        end;
        UpdateHeader;
      end;
    KIND_CAL:
      begin
        if not T.OKs[0] then
        begin
          AddLog('Kalender online tidak tersedia, memakai jadwal bawaan (FOMC 2026 & NFP).', clrMuted);
          Exit;
        end;
        SetLength(ev, 0);
        k := ParseFFCalendar(T.Results[0], ev);
        nowU := NowUTC;
        { kalender online mencakup minggu ini: buang jadwal bawaan pada rentang yang sama }
        if Length(ev) > 0 then
        begin
          wMin := ev[0].TimeU; wMax := ev[0].TimeU;
          for i := 0 to High(ev) do begin wMin := Min(wMin, ev[i].TimeU); wMax := Max(wMax, ev[i].TimeU); end;
          for j := 0 to High(FEvents) do
            if FEvents[j].Builtin and (FEvents[j].TimeU >= wMin - 0.5) and (FEvents[j].TimeU <= wMax + 0.5) then
              FEvents[j].TimeU := -1;
        end;
        { gabungkan: hapus event bawaan NFP/FOMC bila sudah ada versi online di hari yang sama }
        for i := 0 to High(ev) do
        begin
          dup := False;
          for j := 0 to High(FEvents) do
            if (not FEvents[j].Builtin) and (FEvents[j].Title = ev[i].Title) and (Abs(FEvents[j].TimeU - ev[i].TimeU) < 1 / 1440) then
            begin
              FEvents[j].Forecast := ev[i].Forecast;
              FEvents[j].Previous := ev[i].Previous;
              dup := True;
            end;
          if dup then Continue;
          for j := 0 to High(FEvents) do
            if FEvents[j].Builtin and (Trunc(FEvents[j].TimeU) = Trunc(ev[i].TimeU)) and
               (((Pos('Non-Farm', FEvents[j].Title) > 0) and (Pos('Non-Farm', ev[i].Title) > 0)) or
                ((Pos('FOMC Keputusan', FEvents[j].Title) > 0) and (Pos('Federal Funds', ev[i].Title) > 0))) then
              FEvents[j].TimeU := -1;
          n := Length(FEvents);
          SetLength(FEvents, n + 1);
          FEvents[n] := ev[i];
          if (ev[i].TimeU - nowU) * 86400 < -60 then begin FEvents[n].Alert5 := True; FEvents[n].Alert0 := True; end;
        end;
        j := 0;
        for i := 0 to High(FEvents) do
          if FEvents[i].TimeU > 0 then begin FEvents[j] := FEvents[i]; Inc(j); end;
        SetLength(FEvents, j);
        SortEvents(FEvents);
        AddLog(Format('Kalender ekonomi online dimuat: %d berita penting minggu ini.', [k]), clrMuted);
        WriteNews;
      end;
  end;
end;

{ ---------------- Perhitungan & tampilan ---------------- }

procedure TMainForm.Recompute(Full: Boolean);
var n, k, h1, h4: Integer;
begin
  n := Length(FCandles);
  if n < 30 then Exit;
  for k := 0 to 5 do Chart.MA[k] := SMA(FCandles, MAPer[k]);
  Bollinger(FCandles, 20, 2, Chart.BBU, Chart.BBM, Chart.BBL);
  RSI := RSIArr(FCandles, 14);
  MACDArr(FCandles, MacdA, SigA, HistA);
  ATR := ATRArr(FCandles, 14);
  ComputeStructure(FCandles, 3, Chart.Events, FSI);
  ComputeFVG(FCandles, ATR, Chart.FVGs);
  ComputeMarks(FCandles, n - 300, Chart.Marks);
  Chart.Piv := ComputePivots(FCandles, TFSecs[FTF]);
  ComputeCrosses(FCandles, Chart.MA, FCross);
  ChartPatterns(FCandles, ATR[n - 1], FPats);
  h1 := 0; h4 := 0;
  if FMTFInfo[4].OK then h1 := FMTFInfo[4].Trend;
  if FMTFInfo[5].OK then h4 := FMTFInfo[5].Trend;
  FSig := ComputeSignal(FCandles, Chart.MA, Chart.BBU, Chart.BBL, RSI, HistA, ATR, FSI, h1, h4);
  Chart.C := FCandles;
  Chart.Digits := PriceDigits;
  Chart.TFSec := TFSecs[FTF];
  if Abs(FSig.Action) >= 1 then Chart.SigAction := FSig.Action else Chart.SigAction := 0;
  Chart.SigEntry := FSig.Entry; Chart.SigSL := FSig.SL;
  Chart.SigTP1 := FSig.TP1; Chart.SigTP2 := FSig.TP2;
  UpdateHeader;
  if Full then WriteAnalysis;
  lblStatus.Caption := Format('Sumber: %s   %s   %d candle   update %s',
    [FSrc, #149, n, FormatDateTime('hh:nn:ss', Now)]);
  Chart.Invalidate;
end;

procedure TMainForm.UpdateHeader;
var n, i: Integer; last, chg: Double; found: Boolean;
begin
  n := Length(FCandles);
  if n = 0 then Exit;
  last := FCandles[n - 1].C;
  lblPrice.Caption := FmtP(last, PriceDigits);
  found := False; chg := 0;
  if FIsGold then
  begin
    if FGoldTick.Last > 0 then begin chg := FGoldTick.Chg; found := True; end;
  end
  else
    for i := 0 to High(FTick) do
      if FTick[i].Sym = FSym then begin chg := FTick[i].Chg; found := True; Break; end;
  if found then
  begin
    lblChg.Caption := FormatFloat('+0.00;-0.00', chg) + '% (24j)';
    lblChg.Font.Color := DirCol(Sign(chg));
    lblPrice.Font.Color := DirCol(Sign(chg));
  end;
  case FSig.Action of
    2: begin lblSignal.Caption := Format('SINYAL: STRONG BUY  (skor %s)', [SgnI(FSig.Score)]); lblSignal.Font.Color := clrGreen; end;
    1: begin lblSignal.Caption := Format('SINYAL: BUY lemah - tunggu konfirmasi  (skor %s)', [SgnI(FSig.Score)]); lblSignal.Font.Color := RGB(120, 220, 170); end;
   -1: begin lblSignal.Caption := Format('SINYAL: SELL lemah - tunggu konfirmasi  (skor %s)', [SgnI(FSig.Score)]); lblSignal.Font.Color := RGB(255, 140, 150); end;
   -2: begin lblSignal.Caption := Format('SINYAL: STRONG SELL  (skor %s)', [SgnI(FSig.Score)]); lblSignal.Font.Color := clrRed; end;
  else
    begin lblSignal.Caption := Format('SINYAL: WAIT / NETRAL  (skor %s)', [SgnI(FSig.Score)]); lblSignal.Font.Color := clrYellow; end;
  end;
  lblCount.Caption := DirTxt(FSI.Trend) + ' ' + DurStr((n - 1 - FSI.TrendStart) * TFSecs[FTF]);
  lblCount.Font.Color := DirCol(FSI.Trend);
end;

function TMainForm.TimeStrU(U: TDateTime): string;
begin
  Result := FormatDateTime('ddd dd mmm hh:nn', ToLocal(U));
end;

function TMainForm.HighImpactSoon(Minutes: Integer; out Ev: TEcoEvent): Boolean;
var i: Integer; nowU: TDateTime;
begin
  Result := False;
  nowU := NowUTC;
  for i := 0 to High(FEvents) do
    if IsAlarmEvent(FEvents[i]) and (FEvents[i].TimeU > nowU - 15 / 1440) and (FEvents[i].TimeU < nowU + Minutes / 1440) then
    begin
      Ev := FEvents[i];
      Result := True;
      Exit;
    end;
end;

procedure TMainForm.WriteAnalysis;
var R: TRichEdit; n, i, k, d, dir, cnt, bars: Integer; c, pip, risk, hi50, lo50, vAvg, er, path, bw, bwMin: Double;
    sl: TStringList; s: string; ok: Boolean; pm: TPatMark; ev: TEcoEvent; st: TSessState; london: Boolean;
    nearF: Boolean;

  procedure Chk(B: Boolean; const Txt: string);
  begin
    if B then begin REL(R, '  [v]  ' + Txt, clrGreen); Inc(cnt); end
    else REL(R, '  [x]  ' + Txt, RGB(255, 110, 125));
  end;

  function Pp(V: Double): string;
  begin
    Result := FormatFloat('0.0', V / pip) + ' pips';
  end;

begin
  n := Length(FCandles);
  if n < 60 then Exit;
  R := reAnal;
  d := PriceDigits; pip := PipSize; c := FCandles[n - 1].C;
  REBegin(R);
  REL(R, FDispSym + '  ' + #149 + '  TF ' + TFLabels[FTF] + '  ' + #149 + '  ' + FmtP(c, d), clrText, True, 12);

  case FSig.Action of
    2: REL(R, 'STRONG BUY', clrGreen, True, 16);
    1: REL(R, 'BUY (lemah) - tunggu konfirmasi', RGB(120, 220, 170), True, 14);
   -1: REL(R, 'SELL (lemah) - tunggu konfirmasi', RGB(255, 140, 150), True, 14);
   -2: REL(R, 'STRONG SELL', clrRed, True, 16);
  else REL(R, 'WAIT / NETRAL', clrYellow, True, 16);
  end;
  REKV(R, 'Skor sinyal: ', Format('%s  (BUY kuat >= +6, SELL kuat <= -6)', [SgnI(FSig.Score)]), DirCol(Sign(FSig.Score)));

  { tren & durasi }
  REH(R, 'KONDISI PASAR (BULLISH / BEARISH)');
  bars := n - 1 - FSI.TrendStart;
  REIn(R, '  ' + DirTxt(FSI.Trend), DirCol(FSI.Trend), True, 13);
  REL(R, Format('  sudah berlangsung %d candle (~ %s)', [bars, DurStr(bars * TFSecs[FTF])]), clrText);
  REKV(R, '  Dimulai sejak: ', TimeStrU(FCandles[FSI.TrendStart].T / 86400000 + 25569), clrText);
  path := 0;
  for i := n - 20 to n - 1 do path := path + Abs(FCandles[i].C - FCandles[i - 1].C);
  if path > 0 then er := Abs(c - FCandles[n - 21].C) / path else er := 0;
  REKV(R, '  Kekuatan tren (20 candle): ',
    Sx(er > 0.5, 'KUAT', Sx(er > 0.3, 'SEDANG', 'LEMAH / SIDEWAYS')) + Format('  (ER %.2f, gerak %s)', [er, Pp(c - FCandles[n - 21].C)]),
    Cx(er > 0.3, DirCol(Sign(c - FCandles[n - 21].C)), clrYellow));
  if (Length(FCross) > 0) and (FCross[0].Idx >= 0) then
  begin
    k := n - 1 - FCross[0].Idx;
    REKV(R, '  MA9 vs MA25: ', Format('%s sejak %d candle (~ %s)',
      [Sx(FCross[0].Dir > 0, 'MA9 di ATAS MA25 (bullish)', 'MA9 di BAWAH MA25 (bearish)'), k, DurStr(k * TFSecs[FTF])]), DirCol(FCross[0].Dir));
  end;

  { rencana }
  REH(R, 'RENCANA TRADING (RR minimal 1:2)');
  if FSig.Score >= 0 then dir := 1 else dir := -1;
  risk := Abs(FSig.Entry - FSig.SL);
  REKV(R, '  Arah: ', Sx(dir > 0, 'BUY', 'SELL') + Sx(Abs(FSig.Action) = 2, '  (setup kuat)', Sx(FSig.Action = 0, '  (belum valid - hanya simulasi)', '  (lemah)')), DirCol(dir));
  REKV(R, '  Entry: ', FmtP(FSig.Entry, d), clrText);
  REKV(R, '  Stop Loss: ', FmtP(FSig.SL, d) + '   (' + Pp(risk) + ')', clrRed);
  REKV(R, '  Take Profit 1 (1:2): ', FmtP(FSig.TP1, d) + '   (' + Pp(2 * risk) + ')', clrGreen);
  REKV(R, '  Take Profit 2 (1:3): ', FmtP(FSig.TP2, d) + '   (' + Pp(3 * risk) + ')', clrGreen);
  if ATR[n - 1] > 0 then
    REKV(R, '  Estimasi waktu capai TP1: ', '~ ' + DurStr(2 * risk / ATR[n - 1] * 1.6 * TFSecs[FTF]) +
      '  (ATR ' + Pp(ATR[n - 1]) + ' / candle)', clrText);

  { rahasia jitu }
  REH(R, 'RAHASIA JITU SEBELUM ' + Sx(dir > 0, 'BUY', 'SELL') + ' (checklist)');
  cnt := 0;
  Chk(FMTFInfo[5].OK and (FMTFInfo[5].Trend = dir), 'Tren timeframe besar (4H) searah');
  Chk(FSI.Trend = dir, 'Struktur SMC (BOS/CHoCH) searah');
  hi50 := FCandles[n - 50].H; lo50 := FCandles[n - 50].L;
  for i := n - 50 to n - 1 do begin hi50 := Max(hi50, FCandles[i].H); lo50 := Min(lo50, FCandles[i].L); end;
  if dir > 0 then Chk(c < (hi50 + lo50) / 2, 'Harga di zona DISCOUNT (< 50% range) - beli murah')
  else Chk(c > (hi50 + lo50) / 2, 'Harga di zona PREMIUM (> 50% range) - jual mahal');
  nearF := False;
  for i := 0 to High(Chart.FVGs) do
    with Chart.FVGs[i] do
      if (EndIdx = -1) and (Dir = dir) and (Abs(c - (Top + Bot) / 2) < 1.5 * ATR[n - 1]) then nearF := True;
  if dir > 0 then nearF := nearF or (Abs(c - Chart.Piv.S1) < ATR[n - 1]) or (Abs(c - Chart.Piv.P) < 0.5 * ATR[n - 1])
  else nearF := nearF or (Abs(c - Chart.Piv.R1) < ATR[n - 1]) or (Abs(c - Chart.Piv.P) < 0.5 * ATR[n - 1]);
  Chk(nearF, 'Dekat area entry (FVG / Support-Resistance / Pivot)');
  vAvg := 0;
  for i := n - 22 to n - 3 do vAvg := vAvg + FCandles[i].V;
  vAvg := vAvg / 20;
  Chk(FCandles[n - 2].V > vAvg, Format('Volume candle terakhir > rata-rata (%.1fx)', [FCandles[n - 2].V / Max(vAvg, 1E-12)]));
  if dir > 0 then Chk(RSI[n - 1] < 70, Format('RSI %.1f belum overbought', [RSI[n - 1]]))
  else Chk(RSI[n - 1] > 30, Format('RSI %.1f belum oversold', [RSI[n - 1]]));
  ok := False;
  for i := n - 4 to n - 2 do
    if DetectCandle(FCandles, i, pm) and (pm.Dir = dir) then ok := True;
  Chk(ok, 'Ada konfirmasi pola candle searah (3 candle terakhir)');
  london := False;
  st := GetSessState(2, NowUTC); if st.IsOpen then london := True;
  st := GetSessState(3, NowUTC); if st.IsOpen then london := True;
  Chk(london, 'Sesi London / New York aktif (volatilitas XAU tinggi)');
  Chk(not HighImpactSoon(30, ev), 'Tidak ada berita high-impact 30 menit ke depan');
  if dir > 0 then Chk((Chart.MA[0][n - 1] > Chart.MA[1][n - 1]) and (Chart.MA[1][n - 1] > Chart.MA[2][n - 1]), 'MA tersusun naik (MA9 > MA25 > MA99)')
  else Chk((Chart.MA[0][n - 1] < Chart.MA[1][n - 1]) and (Chart.MA[1][n - 1] < Chart.MA[2][n - 1]), 'MA tersusun turun (MA9 < MA25 < MA99)');
  if cnt >= 8 then REL(R, Format('  => %d/10 terpenuhi: SANGAT LAYAK ENTRY', [cnt]), clrGreen, True, 10)
  else if cnt >= 6 then REL(R, Format('  => %d/10 terpenuhi: LAYAK, tetapi hati-hati & kecilkan lot', [cnt]), clrYellow, True, 10)
  else REL(R, Format('  => %d/10 terpenuhi: JANGAN ENTRY DULU, tunggu setup lebih baik', [cnt]), clrRed, True, 10);
  REL(R, '  Rahasia: tunggu candle CLOSE, jangan kejar harga, entry saat RETEST, selalu pasang SL, risiko maks 1-2%.', clrMuted);
  if HighImpactSoon(30, ev) then
    REL(R, '  PERINGATAN BERITA: ' + ev.Title + ' (' + TimeStrU(ev.TimeU) + ')', RGB(255, 145, 0), True);

  { alasan skor }
  REH(R, 'ALASAN SINYAL');
  sl := TStringList.Create;
  try
    sl.Text := FSig.Reasons;
    for i := 0 to sl.Count - 1 do
      if sl[i] <> '' then
      begin
        if sl[i][1] = '+' then REL(R, '  ' + sl[i], clrGreen)
        else if sl[i][1] = '-' then REL(R, '  ' + sl[i], RGB(255, 110, 125))
        else REL(R, '  ' + sl[i], clrMuted);
      end;
  finally
    sl.Free;
  end;

  { SMC }
  REH(R, 'SMART MONEY: BOS / CHoCH / FVG');
  k := 0;
  for i := High(Chart.Events) downto 0 do
  begin
    with Chart.Events[i] do
      REL(R, Format('  %s %s  di %s  (%s, %d candle lalu)',
        [Sx(Kind = 2, 'CHoCH', 'BOS  '), Sx(Dir > 0, 'BULLISH', 'BEARISH'), FmtP(Level, d),
         TimeStrU(FCandles[ToIdx].T / 86400000 + 25569), n - 1 - ToIdx]),
        Cx(Kind = 2, RGB(255, 196, 0), DirCol(Dir)), Kind = 2);
    Inc(k);
    if k >= 4 then Break;
  end;
  k := 0;
  for i := High(Chart.FVGs) downto 0 do
    with Chart.FVGs[i] do
      if EndIdx = -1 then
      begin
        REL(R, Format('  FVG %s aktif: %s - %s  (jarak %s)',
          [Sx(Dir > 0, 'BULLISH', 'BEARISH'), FmtP(Bot, d), FmtP(Top, d), Pp(Abs(c - (Top + Bot) / 2))]), DirCol(Dir));
        Inc(k);
        if k >= 4 then Break;
      end;
  if k = 0 then REL(R, '  Tidak ada FVG aktif yang belum terisi.', clrMuted);

  { S/R }
  REH(R, 'SUPPORT & RESISTANCE (Pivot)');
  with Chart.Piv do
  begin
    REKV(R, '  R3: ', FmtP(R3, d) + '   (' + Pp(R3 - c) + ')', RGB(255, 82, 82));
    REKV(R, '  R2: ', FmtP(R2, d) + '   (' + Pp(R2 - c) + ')', RGB(255, 120, 120));
    REKV(R, '  R1: ', FmtP(R1, d) + '   (' + Pp(R1 - c) + ')', RGB(255, 160, 160));
    REKV(R, '  Pivot: ', FmtP(P, d) + '   (' + Pp(P - c) + ')', clrYellow);
    REKV(R, '  S1: ', FmtP(S1, d) + '   (' + Pp(S1 - c) + ')', RGB(130, 230, 180));
    REKV(R, '  S2: ', FmtP(S2, d) + '   (' + Pp(S2 - c) + ')', RGB(60, 210, 150));
    REKV(R, '  S3: ', FmtP(S3, d) + '   (' + Pp(S3 - c) + ')', RGB(0, 180, 110));
  end;

  { indikator }
  REH(R, 'INDIKATOR');
  REKV(R, '  RSI(14): ', Format('%.1f  %s', [RSI[n - 1], Sx(RSI[n - 1] > 70, 'OVERBOUGHT', Sx(RSI[n - 1] < 30, 'OVERSOLD', 'normal'))]),
    Cx(RSI[n - 1] > 50, clrGreen, clrRed));
  REKV(R, '  MACD(12,26,9): ', Format('%s  hist %s  %s', [FmtP(MacdA[n - 1], d), FmtP(HistA[n - 1], d), Sx(HistA[n - 1] > 0, 'bullish', 'bearish')]),
    DirCol(Sign(HistA[n - 1])));
  if (Chart.BBU[n - 1] > Chart.BBL[n - 1]) and (Chart.BBM[n - 1] > 0) then
  begin
    bw := (Chart.BBU[n - 1] - Chart.BBL[n - 1]) / Chart.BBM[n - 1] * 100;
    bwMin := bw;
    for i := n - 100 to n - 1 do
      if (i > 20) and (Chart.BBM[i] > 0) then bwMin := Min(bwMin, (Chart.BBU[i] - Chart.BBL[i]) / Chart.BBM[i] * 100);
    REKV(R, '  Bollinger: ', Format('%%B %.0f%%  lebar %.2f%%', [(c - Chart.BBL[n - 1]) / (Chart.BBU[n - 1] - Chart.BBL[n - 1]) * 100, bw]), clrText);
    if bw <= bwMin * 1.1 then REL(R, '  BOLLINGER SQUEEZE: band sangat sempit -> siap breakout besar!', RGB(255, 145, 0), True)
    else if c > Chart.BBU[n - 1] then REL(R, '  Harga di atas band atas (kuat naik / jenuh beli)', clrGreen)
    else if c < Chart.BBL[n - 1] then REL(R, '  Harga di bawah band bawah (kuat turun / jenuh jual)', clrRed);
  end;
  REKV(R, '  ATR(14): ', Pp(ATR[n - 1]) + ' per candle', clrText);

  { persilangan }
  REH(R, 'BERITA PERSILANGAN MA (Golden / Death Cross)');
  for i := 0 to High(FCross) do
    with FCross[i] do
    begin
      if Idx >= 0 then
      begin
        k := n - 1 - Idx;
        if k <= 60 then
          REL(R, Format('  %s MA%d x MA%d  %d candle lalu (~ %s) -> %s',
            [Sx(Dir > 0, 'GOLDEN CROSS', 'DEATH CROSS '), Fast, Slow, k, DurStr(k * TFSecs[FTF]),
             Sx(Dir > 0, 'mendorong NAIK', 'mendorong TURUN')]), DirCol(Dir), k <= 10)
        else
          REL(R, Format('  MA%d %s MA%d sejak %d candle (~ %s)', [Fast, Sx(Dir > 0, 'di atas', 'di bawah'), Slow, k, DurStr(k * TFSecs[FTF])]), clrMuted);
      end;
      if Soon then
        REL(R, Format('  AKAN TERJADI: MA%d mendekati MA%d, perkiraan ~%d candle (~ %s) -> potensi %s',
          [Fast, Slow, SoonBars, DurStr(SoonBars * TFSecs[FTF]), Sx(SoonDir > 0, 'NAIK (golden cross)', 'TURUN (death cross)')]),
          RGB(255, 145, 0), True);
    end;

  { pola candle }
  REH(R, 'POLA CANDLE TERAKHIR');
  k := 0;
  for i := High(Chart.Marks) downto 0 do
  begin
    pm := Chart.Marks[i];
    REIn(R, Format('  %s  %s: ', [TimeStrU(FCandles[pm.Idx].T / 86400000 + 25569), pm.Name]), DirCol(pm.Dir), True);
    REL(R, pm.Meaning, clrText);
    Inc(k);
    if k >= 6 then Break;
  end;
  if k = 0 then REL(R, '  Belum ada pola candle signifikan.', clrMuted);

  { pola grafik }
  REH(R, 'POLA GRAFIK (Chart Pattern)');
  if Length(FPats) = 0 then REL(R, '  Tidak ada pola besar terdeteksi saat ini.', clrMuted);
  for i := 0 to High(FPats) do
  begin
    REL(R, '  ' + FPats[i].Name, DirCol(FPats[i].Dir), True);
    REL(R, '     ' + FPats[i].Desc, clrText);
  end;

  REL(R, '', clrText);
  REL(R, 'Grafik = probabilitas, bukan kepastian. Selalu gunakan manajemen risiko.', clrMuted);
  REEnd(R);
end;

procedure TMainForm.WriteMTF;
const TFN: array[0..6] of string = ('1m ', '5m ', '15m', '30m', '1H ', '4H ', '1D ');
var R: TRichEdit; i, best, bull, bear: Integer; sc, bs: Double; inf: TTFInfo; s: string;
begin
  R := reMTF;
  REBegin(R);
  REL(R, 'ANALISA MULTI TIMEFRAME  ' + #149 + '  ' + FDispSym, clrYellow, True, 12);
  REL(R, Sx(FIsGold, '1 pip XAU = 0.10 USD', '1 pip = 0.01% harga (basis point)'), clrMuted);
  REL(R, '', clrText);
  bull := 0; bear := 0;
  for i := 0 to 6 do
  begin
    inf := FMTFInfo[i];
    if not inf.OK then begin REL(R, TFN[i] + '  data belum tersedia', clrMuted); Continue; end;
    if inf.Trend > 0 then Inc(bull) else if inf.Trend < 0 then Inc(bear);
    REIn(R, 'TF ' + Trim(TFN[i]) + '   ', clrText, True, 11);
    REIn(R, DirTxt(inf.Trend), DirCol(inf.Trend), True, 11);
    if inf.Sideways then REL(R, '   (sideways / konsolidasi)', clrYellow, True) else REL(R, '   (trending)', clrGreen);
    REL(R, Format('   Naik-turun rata-rata %.0f pips / candle  ' + #149 + '  ATR %.0f pips', [inf.AvgRangeP, inf.ATRp]), clrText);
    REL(R, Format('   Range 20 candle: %.0f pips (~ %s)  ' + #149 + '  gerak bersih %s pips', [inf.Range20P, DurStr(20 * TFSecs[i]), FormatFloat('+0;-0;0', inf.Chg20P)]),
      DirCol(Sign(inf.Chg20P)));
    REL(R, Format('   Tren berjalan %d candle (~ %s)  ' + #149 + '  ER %.2f  ' + #149 + '  RSI %.0f',
      [inf.TrendBars, DurStr(inf.TrendBars * TFSecs[i]), inf.ER, inf.RSI]), clrMuted);
    if inf.Sideways then
      REL(R, Format('   Sideways: range +/- %.0f pips -> BUY dekat bawah range, SELL dekat atas range', [inf.Range20P]), RGB(255, 196, 0));
  end;

  REH(R, 'KESIMPULAN');
  if bull > bear then REL(R, Format('  Mayoritas timeframe BULLISH (%d naik vs %d turun)', [bull, bear]), clrGreen, True)
  else if bear > bull then REL(R, Format('  Mayoritas timeframe BEARISH (%d turun vs %d naik)', [bear, bull]), clrRed, True)
  else REL(R, '  Timeframe campuran - pasar belum punya arah jelas', clrYellow, True);

  best := -1; bs := 0;
  for i := 1 to 5 do
    if FMTFInfo[i].OK and (FMTFInfo[i].Trend <> 0) then
    begin
      sc := FMTFInfo[i].ER * (1 + 0.15 * i);
      if FMTFInfo[6].OK and (FMTFInfo[6].Trend = FMTFInfo[i].Trend) then sc := sc * 1.3;
      if FMTFInfo[5].OK and (FMTFInfo[5].Trend = FMTFInfo[i].Trend) then sc := sc * 1.2;
      if sc > bs then begin bs := sc; best := i; end;
    end;
  if best >= 0 then
  begin
    inf := FMTFInfo[best];
    REL(R, Format('  TIMEFRAME TERBAIK: %s  (%s, ER %.2f%s)', [Trim(TFN[best]), DirTxt(inf.Trend), inf.ER,
      Sx(FMTFInfo[5].Trend = inf.Trend, ', searah 4H', '')]), DirCol(inf.Trend), True, 11);
    REL(R, Format('  Perkiraan gerak 1 candle %s: %.0f pips. Target 100 pips butuh ~ %s.',
      [Trim(TFN[best]), inf.AvgRangeP, DurStr(100 / Max(inf.ATRp, 0.1) * TFSecs[best] * 1.5)]), clrText);
  end
  else
    REL(R, '  Semua timeframe sideways -> gunakan strategi RANGE (beli di support, jual di resistance).', clrYellow, True);
  s := '';
  for i := 0 to 6 do
    if FMTFInfo[i].OK and FMTFInfo[i].Sideways then s := s + Trim(TFN[i]) + ' ';
  if s <> '' then REL(R, '  TF sideways: ' + s, RGB(255, 196, 0));
  REL(R, '  Tips: TF besar (4H/1D) menentukan arah, TF kecil (5m/15m) untuk timing entry.', clrMuted);
  REEnd(R);
end;

procedure TMainForm.WriteNews;
var R: TRichEdit; i, cnt: Integer; nowU: TDateTime; secs: Double; col: TColor;
begin
  R := reNews;
  REBegin(R);
  REL(R, 'KALENDER BERITA EKONOMI (FOMC, NFP, CPI, dll)', clrYellow, True, 11);
  REL(R, 'Alarm otomatis 5 menit sebelum & saat rilis berita berdampak tinggi.', clrMuted);
  nowU := NowUTC;
  cnt := 0;
  for i := 0 to High(FEvents) do
  begin
    if (FEvents[i].TimeU < nowU - 1) or (FEvents[i].TimeU > nowU + 35) then Continue;
    secs := (FEvents[i].TimeU - nowU) * 86400;
    if FEvents[i].Impact = 'High' then col := clrRed else col := RGB(255, 145, 0);
    REL(R, '', clrText, False, 3);
    REIn(R, TimeStrU(FEvents[i].TimeU) + '  ', clrText, True);
    if secs > 0 then REIn(R, '(dalam ' + CountdownStr(secs) + ')  ', clrYellow)
    else REIn(R, '(sudah rilis)  ', clrMuted);
    REL(R, '[' + FEvents[i].Country + ' ' + FEvents[i].Impact + ']', col, True);
    REL(R, '  ' + FEvents[i].Title, Cx(IsAlarmEvent(FEvents[i]), clWhite, clrText), IsAlarmEvent(FEvents[i]));
    if (FEvents[i].Forecast <> '') or (FEvents[i].Previous <> '') then
      REL(R, '  Forecast: ' + FEvents[i].Forecast + '   Sebelumnya: ' + FEvents[i].Previous, clrMuted);
    if (FEvents[i].Country = 'USD') or (FEvents[i].Country = 'USER') then
      REL(R, '  Dampak XAU: ' + EventImpactText(FEvents[i].Title), RGB(0, 188, 212));
    Inc(cnt);
    if cnt >= 40 then Break;
  end;
  if cnt = 0 then REL(R, 'Tidak ada berita penting dalam waktu dekat.', clrMuted);
  REEnd(R);
end;

procedure TMainForm.ComputeSessRanges;
var s, d, i, cnt: Integer; A: TCandles; o, c: TDateTime; hi, lo, op, cl, sumR, sumM: Double; t: TDateTime; any: Boolean;
begin
  A := FMTF[4];
  for s := 0 to 3 do begin FSessRange[s] := 0; FSessMove[s] := 0; end;
  if Length(A) < 48 then Exit;
  for s := 0 to 3 do
  begin
    cnt := 0; sumR := 0; sumM := 0;
    for d := 1 to 12 do
    begin
      t := Trunc(NowUTC) - d;
      if DayOfTheWeek(t) >= 6 then Continue;
      SessionWindow(s, t, o, c);
      any := False; hi := 0; lo := 0; op := 0; cl := 0;
      for i := 0 to High(A) do
        if (A[i].T / 86400000 + 25569 >= o - 1E-6) and (A[i].T / 86400000 + 25569 < c - 1E-6) then
        begin
          if not any then begin hi := A[i].H; lo := A[i].L; op := A[i].O; any := True; end;
          hi := Max(hi, A[i].H); lo := Min(lo, A[i].L); cl := A[i].C;
        end;
      if any then begin sumR := sumR + (hi - lo); sumM := sumM + Abs(cl - op); Inc(cnt); end;
    end;
    if cnt > 0 then
    begin
      FSessRange[s] := sumR / cnt / PipSize;
      FSessMove[s] := sumM / cnt / PipSize;
    end;
  end;
end;

procedure TMainForm.OnSessPaint(Sender: TObject);
var cv: TCanvas; i, y, x0, x1, w, xs, xe, d: Integer; st: TSessState; nowU, dayL, o, c, lo_, lc_: TDateTime;
    secs: Double; s: string; anyOpen: Integer;
begin
  cv := pbSess.Canvas;
  w := pbSess.Width;
  cv.Brush.Color := clrPanel; cv.FillRect(pbSess.ClientRect);
  cv.Font.Name := 'Segoe UI';
  cv.Brush.Style := bsClear;
  cv.Font.Size := 11; cv.Font.Style := [fsBold]; cv.Font.Color := clrYellow;
  cv.TextOut(4, 2, 'SESI TRADING (' + ZoneName + ')');
  cv.Font.Size := 8; cv.Font.Style := []; cv.Font.Color := clrMuted;
  cv.TextOut(4, 22, 'Jam lokal komputer, otomatis menyesuaikan DST. Alarm 5 menit sebelum pergantian.');
  nowU := NowUTC;
  anyOpen := 0;
  for i := 0 to 3 do
  begin
    y := 42 + i * 40;
    st := GetSessState(i, nowU);
    cv.Brush.Style := bsSolid;
    cv.Brush.Color := Cx(st.IsOpen, RGB(22, 40, 34), clrPanel2);
    cv.Pen.Color := Cx(st.IsOpen, SessColors[i], clrBorder);
    cv.RoundRect(2, y, w - 2, y + 36, 6, 6);
    cv.Brush.Color := Cx(st.IsOpen, clrGreen, clrMuted);
    cv.Pen.Color := cv.Brush.Color;
    cv.Ellipse(10, y + 13, 20, y + 23);
    cv.Brush.Style := bsClear;
    cv.Font.Size := 10; cv.Font.Style := [fsBold]; cv.Font.Color := SessColors[i];
    cv.TextOut(28, y + 2, SessName[i]);
    cv.Font.Size := 8; cv.Font.Style := []; cv.Font.Color := clrText;
    cv.TextOut(28, y + 19, FormatDateTime('hh:nn', ToLocal(st.OpenU)) + ' - ' + FormatDateTime('hh:nn', ToLocal(st.CloseU)) + ' ' + ZoneName);
    secs := (st.NextChange - nowU) * 86400;
    if st.IsOpen then
    begin
      Inc(anyOpen);
      s := 'BUKA  ' + #149 + '  tutup dalam ' + CountdownStr(secs);
      cv.Font.Color := Cx(secs <= 300, clrRed, clrGreen);
    end
    else
    begin
      s := 'TUTUP  ' + #149 + '  buka dalam ' + CountdownStr(secs);
      cv.Font.Color := Cx(secs <= 300, RGB(255, 145, 0), clrMuted);
    end;
    cv.Font.Style := [fsBold];
    cv.TextOut(150, y + 3, s);
    cv.Font.Style := []; cv.Font.Color := clrMuted;
    if FSessRange[i] > 0 then
      cv.TextOut(150, y + 19, Format('Rata2 range %.0f pips, gerak %.0f pips / %.0f jam',
        [FSessRange[i], FSessMove[i], SessCloseH[i] - SessOpenH[i]]));
  end;

  { garis waktu 24 jam }
  y := 210;
  x0 := 10; x1 := w - 10;
  cv.Font.Color := clrMuted; cv.Font.Size := 7;
  dayL := Trunc(ToLocal(nowU));
  for i := 0 to 8 do
  begin
    xs := x0 + Round((x1 - x0) * i * 3 / 24);
    cv.TextOut(xs - 6, y, Format('%.2d', [i * 3 mod 24]));
    cv.Pen.Color := clrBorder;
    cv.MoveTo(xs, y + 12); cv.LineTo(xs, y + 12 + 4 * 14);
  end;
  for i := 0 to 3 do
    for d := -1 to 1 do
    begin
      if DayOfTheWeek(Trunc(nowU) + d) >= 6 then Continue;
      SessionWindow(i, Trunc(nowU) + d, o, c);
      lo_ := ToLocal(o) - dayL; lc_ := ToLocal(c) - dayL;
      if (lc_ <= 0) or (lo_ >= 1) then Continue;
      if lo_ < 0 then lo_ := 0;
      if lc_ > 1 then lc_ := 1;
      xs := x0 + Round((x1 - x0) * lo_); xe := x0 + Round((x1 - x0) * lc_);
      cv.Brush.Style := bsSolid; cv.Brush.Color := SessColors[i];
      cv.FillRect(Rect(xs, y + 14 + i * 14, xe, y + 24 + i * 14));
      cv.Brush.Style := bsClear; cv.Font.Color := clWhite;
      if xe - xs > 50 then cv.TextOut(xs + 3, y + 13 + i * 14, SessName[i]);
    end;
  xs := x0 + Round((x1 - x0) * (ToLocal(nowU) - dayL));
  cv.Pen.Color := clrYellow; cv.Pen.Width := 2;
  cv.MoveTo(xs, y + 10); cv.LineTo(xs, y + 14 + 4 * 14);
  cv.Pen.Width := 1;
  cv.Font.Size := 8; cv.Font.Color := clrYellow; cv.Font.Style := [fsBold];
  y := y + 14 + 4 * 14 + 6;
  if GetSessState(2, nowU).IsOpen and GetSessState(3, nowU).IsOpen then
    cv.TextOut(4, y, 'OVERLAP LONDON - NEW YORK: volatilitas XAU paling tinggi!')
  else if anyOpen = 0 then
    cv.TextOut(4, y, 'Pasar sepi / di luar sesi utama - spread bisa melebar.')
  else
    cv.TextOut(4, y, 'Pantau pergantian sesi: volatilitas naik saat sesi baru buka.');
  cv.Font.Style := [];
end;

{ ---------------- Scanner ---------------- }

function TickerCmp(const A, B: TTicker; Mode: Integer): Integer;
begin
  case Mode of
    0: Result := CompareValue(B.Chg, A.Chg);
    1: Result := CompareValue(A.Chg, B.Chg);
    2: begin Result := B.Status - A.Status; if Result = 0 then Result := CompareValue(B.Pos, A.Pos); end;
    3: begin Result := A.Status - B.Status; if Result = 0 then Result := CompareValue(A.Pos, B.Pos); end;
    4: Result := CompareValue(B.QVol, A.QVol);
  else
    Result := CompareStr(A.Sym, B.Sym);
  end;
end;

procedure TMainForm.ApplyFilter;
var i, j, n, mode, gap: Integer; q, sec: string; t: TTicker; ok: Boolean;
begin
  q := Trim(edSearch.Text);
  case cbSector.ItemIndex of
    1: sec := SecMajor; 2: sec := SecL1; 3: sec := SecL2; 4: sec := SecMeme;
    5: sec := SecAI; 6: sec := SecDeFi; 7: sec := SecGold;
  else sec := '';
  end;
  SetLength(FView, Length(FTick));
  n := 0;
  for i := 0 to High(FTick) do
    with FTick[i] do
    begin
      if Copy(Sym, Length(Sym) - 3, 4) <> 'USDT' then Continue;
      if (Last <= 0) or not IsAscii(Sym) then Continue;
      if (System.Pos(' ' + Base + ' ', StableBases) > 0) then Continue;
      if (System.Pos('UP', Base) > 0) and (Copy(Base, Length(Base) - 1, 2) = 'UP') and (Length(Base) > 3) then Continue;
      if (Copy(Base, Length(Base) - 3, 4) = 'DOWN') then Continue;
      if (QVol < 1000000) and not IsGold then Continue;
      if (q <> '') and (System.Pos(q, Sym) = 0) then Continue;
      if (sec <> '') and (System.Pos(' ' + Base + ' ', sec) = 0) then Continue;
      case FCat of
        1: ok := Chg > 0;
        2: ok := Chg < 0;
        3: ok := Status = 1;
        4: ok := Status = -1;
      else ok := True;
      end;
      if not ok then Continue;
      FView[n] := FTick[i];
      Inc(n);
    end;
  SetLength(FView, n);
  mode := cbSort.ItemIndex;
  case FCat of
    1: mode := 0; 2: mode := 1; 3: mode := 2; 4: mode := 3; 5: mode := 4;
  end;
  gap := n div 2;
  while gap > 0 do
  begin
    for i := gap to n - 1 do
    begin
      t := FView[i];
      j := i;
      while (j >= gap) and (TickerCmp(FView[j - gap], t, mode) > 0) do
      begin
        FView[j] := FView[j - gap];
        Dec(j, gap);
      end;
      FView[j] := t;
    end;
    gap := gap div 2;
  end;
  grid.RowCount := Max(2, n + 1);
  grid.Invalidate;
end;

procedure TMainForm.OnGridDraw(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
const Hdr: array[0..3] of string = ('Koin', 'Harga', '24j %', 'Status');
var cv: TCanvas; t: TTicker; s: string; col: TColor; x, bw: Integer;
begin
  cv := grid.Canvas;
  cv.Font.Name := 'Segoe UI'; cv.Font.Size := 8; cv.Font.Style := [];
  if ARow = 0 then
  begin
    cv.Brush.Color := clrPanel2; cv.FillRect(Rect);
    cv.Font.Color := clrMuted;
    cv.TextOut(Rect.Left + 6, Rect.Top + 5, Hdr[ACol]);
    Exit;
  end;
  if ARow - 1 > High(FView) then
  begin
    cv.Brush.Color := clrPanel; cv.FillRect(Rect);
    if (ARow = 1) and (ACol = 0) then
    begin
      cv.Font.Color := clrMuted;
      cv.TextOut(Rect.Left + 6, Rect.Top + 5, Sx(FTickN = 0, 'Memuat...', 'Tidak ada'));
    end;
    Exit;
  end;
  t := FView[ARow - 1];
  if ARow = grid.Row then cv.Brush.Color := clrPanel2
  else if t.IsGold then cv.Brush.Color := RGB(38, 33, 16)
  else cv.Brush.Color := clrPanel;
  cv.FillRect(Rect);
  cv.Brush.Style := bsClear;
  col := DirCol(Sign(t.Chg));
  case ACol of
    0: begin
         cv.Font.Style := [fsBold];
         cv.Font.Color := Cx(t.IsGold, clrGold, clrText);
         cv.TextOut(Rect.Left + 6, Rect.Top + 1, t.Base);
         cv.Font.Style := []; cv.Font.Size := 7; cv.Font.Color := clrMuted;
         cv.TextOut(Rect.Left + 6 + 0, Rect.Top + 12, 'Vol ' + FormatFloat('0.0', t.QVol / 1E6) + 'M');
       end;
    1: begin
         cv.Font.Color := clrText;
         s := FmtP(t.Last, DigitsFor(t.Last));
         cv.TextOut(Rect.Right - cv.TextWidth(s) - 6, Rect.Top + 5, s);
       end;
    2: begin
         s := FormatFloat('+0.00;-0.00', t.Chg) + '%';
         cv.Brush.Style := bsSolid; cv.Brush.Color := col;
         cv.FillRect(Classes.Rect(Rect.Left + 2, Rect.Top + 3, Rect.Right - 2, Rect.Bottom - 3));
         cv.Brush.Style := bsClear; cv.Font.Color := clWhite; cv.Font.Style := [fsBold];
         cv.TextOut((Rect.Left + Rect.Right - cv.TextWidth(s)) div 2, Rect.Top + 5, s);
       end;
    3: begin
         cv.Font.Style := [fsBold];
         if t.Status = 1 then begin cv.Font.Color := clrGreen; s := 'BREAKOUT'; end
         else if t.Status = -1 then begin cv.Font.Color := clrRed; s := 'BREAKDOWN'; end
         else begin cv.Font.Color := clrMuted; cv.Font.Style := []; s := 'range'; end;
         cv.Font.Size := 7;
         cv.TextOut(Rect.Left + 4, Rect.Top + 1, s);
         bw := Rect.Right - Rect.Left - 10;
         cv.Brush.Style := bsSolid; cv.Brush.Color := clrBorder;
         cv.FillRect(Classes.Rect(Rect.Left + 4, Rect.Top + 15, Rect.Left + 4 + bw, Rect.Top + 19));
         x := Rect.Left + 4 + Round(bw * EnsureRange(t.Pos, 0, 1));
         cv.Brush.Color := Cx(t.Pos > 0.5, clrGreen, clrRed);
         cv.FillRect(Classes.Rect(x - 2, Rect.Top + 13, x + 2, Rect.Top + 21));
       end;
  end;
end;

procedure TMainForm.OnGridClick(Sender: TObject);
var r: Integer;
begin
  r := grid.Row - 1;
  if (r < 0) or (r > High(FView)) then Exit;
  if FView[r].IsGold then SelectSymbol('XAUUSDT', True)
  else SelectSymbol(FView[r].Sym, False);
  grid.Invalidate;
end;

{ ---------------- Alarm ---------------- }

procedure TMainForm.AddLog(const Msg: string; Col: TColor);
begin
  if not Assigned(reLog) then Exit;
  if reLog.Lines.Count > 600 then reLog.Clear;
  REIn(reLog, FormatDateTime('dd/mm hh:nn:ss  ', Now), clrMuted);
  REL(reLog, Msg, Col);
  SendMessage(reLog.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TMainForm.Alarm(const Msg: string; Kind: Integer);
var col: TColor;
begin
  case Kind of
    1: col := clrGreen;
   -1: col := clrRed;
    2: col := RGB(41, 121, 255);
    3: col := RGB(255, 145, 0);
  else col := clrYellow;
  end;
  AddLog(Msg, col);
  pnlToast.Color := RGB(GetRValue(ColorToRGB(col)) div 4, GetGValue(ColorToRGB(col)) div 4, GetBValue(ColorToRGB(col)) div 4);
  lblToast.Font.Color := clWhite;
  lblToast.Caption := Msg;
  pnlToast.Left := (pnlCenter.Width - pnlToast.Width) div 2;
  pnlToast.Visible := True;
  pnlToast.BringToFront;
  FToastAt := Now;
  TBeepThread.Create(Kind);
  FlashWindow(Application.Handle, True);
end;

procedure TMainForm.OnToastClick(Sender: TObject);
begin
  pnlToast.Visible := False;
end;

{ saat dibuka, aplikasi langsung tampil paling depan (halaman trading), tidak di belakang jendela lain }
procedure TMainForm.ForceFront;
var fg: HWND; tidFg, tidMe: DWORD;
begin
  if IsIconic(Application.Handle) then Application.Restore;
  WindowState := wsMaximized;
  fg := GetForegroundWindow;
  tidFg := GetWindowThreadProcessId(fg, nil);
  tidMe := GetCurrentThreadId;
  if tidFg <> tidMe then AttachThreadInput(tidMe, tidFg, True);
  { tekan-lepas Alt: cara umum agar Windows mengizinkan jendela ini maju ke depan }
  if GetForegroundWindow <> Handle then
  begin
    keybd_event(VK_MENU, 0, KEYEVENTF_EXTENDEDKEY, 0);
    keybd_event(VK_MENU, 0, KEYEVENTF_EXTENDEDKEY or KEYEVENTF_KEYUP, 0);
  end;
  SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  BringWindowToTop(Handle);
  SetForegroundWindow(Handle);
  if tidFg <> tidMe then AttachThreadInput(tidMe, tidFg, False);
end;

procedure TMainForm.OnTimer1(Sender: TObject);
var i, nx: Integer; nowU, bestT: TDateTime; st: TSessState; secs: Double; s: string;
    act: string; overlap: Boolean;
begin
  if FFrontTicks < 3 then
  begin
    Inc(FFrontTicks);
    ForceFront;
  end;
  nowU := NowUTC;
  lblClock.Caption := FormatDateTime('dddd, dd mmm yyyy  hh:nn:ss', Now) + ' ' + ZoneName;

  { sesi }
  s := ''; nx := -1; bestT := 0; overlap := False;
  for i := 0 to 3 do
  begin
    st := GetSessState(i, nowU);
    if st.IsOpen then
    begin
      if s <> '' then s := s + ' + ';
      s := s + SessName[i];
    end;
    if (nx = -1) or (st.NextChange < bestT) then begin nx := i; bestT := st.NextChange; end;
    secs := (st.NextChange - nowU) * 86400;
    if st.IsOpen then act := 'TUTUP' else act := 'BUKA';
    if (secs > 0) and (secs <= 300) and (Abs(FSessWarned[i] - st.NextChange) > 1 / 86400) then
    begin
      FSessWarned[i] := st.NextChange;
      Alarm(Format('PERHATIAN: 5 menit lagi sesi %s %s (pukul %s %s). Bersiap pergantian sesi!',
        [SessName[i], act, FormatDateTime('hh:nn', ToLocal(st.NextChange)), ZoneName]), 2);
    end;
    if (not FFirstSess) and (st.IsOpen <> FSessOpen[i]) then
      Alarm(Format('Sesi %s sekarang %s.', [SessName[i], Sx(st.IsOpen, 'BUKA', 'TUTUP')]), 2);
    FSessOpen[i] := st.IsOpen;
  end;
  FFirstSess := False;
  overlap := FSessOpen[2] and FSessOpen[3];
  if s = '' then s := 'tidak ada (pasar sepi/akhir pekan)';
  lblSess.Caption := 'Sesi aktif: ' + s + Sx(overlap, '  (OVERLAP - volatil!)', '');
  lblSess.Font.Color := Cx(overlap, clrYellow, Cx(s[1] = 't', clrMuted, clrGreen));
  if nx >= 0 then
  begin
    st := GetSessState(nx, nowU);
    secs := (st.NextChange - nowU) * 86400;
    lblSessNext.Caption := Format('Pergantian berikut: %s %s pukul %s (dalam %s)',
      [SessName[nx], Sx(st.IsOpen, 'TUTUP', 'BUKA'), FormatDateTime('hh:nn', ToLocal(st.NextChange)), CountdownStr(secs)]);
    lblSessNext.Font.Color := Cx(secs <= 300, clrRed, clrMuted);
  end;

  { berita }
  for i := 0 to High(FEvents) do
    if IsAlarmEvent(FEvents[i]) then
    begin
      secs := (FEvents[i].TimeU - nowU) * 86400;
      if (not FEvents[i].Alert5) and (secs > 0) and (secs <= 300) then
      begin
        FEvents[i].Alert5 := True;
        Alarm(Format('BERITA 5 MENIT LAGI: %s [%s] pukul %s. %s', [FEvents[i].Title, FEvents[i].Country,
          FormatDateTime('hh:nn', ToLocal(FEvents[i].TimeU)), EventImpactText(FEvents[i].Title)]), 3);
      end;
      if (not FEvents[i].Alert0) and (secs <= 0) and (secs > -90) then
      begin
        FEvents[i].Alert0 := True;
        FEvents[i].Alert5 := True;
        Alarm(Format('RILIS SEKARANG: %s [%s] - volatilitas tinggi, hati-hati!', [FEvents[i].Title, FEvents[i].Country]), 3);
      end;
      if secs <= -90 then begin FEvents[i].Alert0 := True; FEvents[i].Alert5 := True; end;
    end;

  if pnlToast.Visible and (Now - FToastAt > 20 / 86400) then pnlToast.Visible := False;
  if pages[2].Visible then pbSess.Invalidate;
  Chart.Invalidate;
  UpdateSessInfo;
  UpdateRec;

  if SecondOf(Now) mod 5 = 0 then LoadLive;
  if (SecondOf(Now) = 30) then
  begin
    LoadTickers;
    WriteNews;
  end;
  if (FMainRetry > 0) and (Now >= FMainRetry) then begin FMainRetry := 0; LoadMain; end;
  if (FTickN = 0) and (SecondOf(Now) mod 10 = 0) then LoadTickers;
  if FFapiFail and (Now >= FFapiRetry) then
  begin
    FFapiRetry := Now + 15 / 1440;
    TFetchThread.Create(KIND_PROBE, 0, ['https://fapi.binance.com/fapi/v1/ping'], FetchDone);
  end;
  if (SecondOf(Now) = 0) and (MinuteOf(Now) mod 30 = 0) then LoadCalendar;
  if SecondOf(Now) mod 2 = 0 then UpdateMT5;
end;

procedure TMainForm.OnTimer30(Sender: TObject);
var n, d: Integer; pip: Double;
begin
  LoadMTF;
  n := Length(FCandles);
  if n < 60 then Exit;
  Recompute(True);
  if not btnAlarm.Down then Exit;
  d := PriceDigits; pip := PipSize;
  if Abs(FSig.Action) = 2 then
    Alarm(Format('ALARM %s %s %s @ %s  |  SL %s (%.0f pips)  TP1 %s  TP2 %s  |  skor %s',
      [Sx(FSig.Action > 0, 'BELI (BUY)', 'JUAL (SELL)'), FDispSym, TFLabels[FTF], FmtP(FSig.Entry, d),
       FmtP(FSig.SL, d), Abs(FSig.Entry - FSig.SL) / pip, FmtP(FSig.TP1, d), FmtP(FSig.TP2, d), SgnI(FSig.Score)]), Sign(FSig.Action))
  else if (Abs(FSig.Action) = 1) and (FLastSigAlarm <> FSig.Action) then
    AddLog(Format('Sinyal %s lemah %s %s (skor %s) - tunggu konfirmasi.',
      [Sx(FSig.Action > 0, 'BUY', 'SELL'), FDispSym, TFLabels[FTF], SgnI(FSig.Score)]), DirCol(FSig.Action));
  FLastSigAlarm := FSig.Action;
end;

{ ---------------- Event tombol ---------------- }

procedure TMainForm.OnTF(Sender: TObject);
var i: Integer;
begin
  FTF := TFlatBtn(Sender).Tag;
  OnCapClose(nil);
  for i := 0 to 7 do btnTF[i].Down := i = FTF;
  SetLength(FCandles, 0);
  Chart.C := nil;
  Chart.ResetView;
  LoadMain;
end;

procedure TMainForm.OnInd(Sender: TObject);
var i: Integer;
begin
  if Sender <> nil then
    with TFlatBtn(Sender) do Down := not Down
  else
    for i := 0 to 11 do btnInd[i].Down := True;
  for i := 0 to 5 do
  begin
    btnInd[i].BgDown := MAColors[i];
    btnInd[i].FgDown := clrBg;
    Chart.ShowMA[i] := btnInd[i].Down;
  end;
  Chart.ShowBB := btnInd[6].Down;
  Chart.ShowSR := btnInd[7].Down;
  Chart.ShowSMC := btnInd[8].Down;
  Chart.ShowFVG := btnInd[9].Down;
  Chart.ShowPat := btnInd[10].Down;
  Chart.ShowVol := btnInd[11].Down;
  Chart.Invalidate;
end;

procedure TMainForm.OnZoom(Sender: TObject);
begin
  case TFlatBtn(Sender).Tag of
    1: Chart.ZoomIn;
    2: Chart.ZoomOut;
  else Chart.ResetView;
  end;
end;

procedure TMainForm.OnLink(Sender: TObject);
begin
  ShellExecute(Handle, 'open', PChar(LinkURLs[TFlatBtn(Sender).Tag]), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.OnGold(Sender: TObject);
begin
  SelectSymbol('XAUUSDT', True);
end;

procedure TMainForm.OnAlarmBtn(Sender: TObject);
begin
  btnAlarm.Down := not btnAlarm.Down;
  btnAlarm.Caption := Sx(btnAlarm.Down, 'ALARM 0,5 mnt: ON', 'ALARM 0,5 mnt: OFF');
  AddLog('Alarm sinyal ' + Sx(btnAlarm.Down, 'diaktifkan.', 'dimatikan.'), clrYellow);
end;

procedure TMainForm.OnLeftToggle(Sender: TObject);
begin
  btnLeft.Down := not btnLeft.Down;
  pnlLeft.Visible := btnLeft.Down;
  btnLeft.Caption := Sx(btnLeft.Down, '<<  SEMBUNYIKAN KOIN', '>>  TAMPILKAN KOIN');
  FormResize(nil);
  Chart.Invalidate;
end;

procedure TMainForm.OnRightToggle(Sender: TObject);
begin
  btnRight.Down := not btnRight.Down;
  pnlRight.Visible := btnRight.Down;
  btnRight.Caption := Sx(btnRight.Down, 'SEMBUNYIKAN ANALISA  >>', 'TAMPILKAN ANALISA  <<');
  FormResize(nil);
  Chart.Invalidate;
end;

procedure TMainForm.OnCat(Sender: TObject);
var i: Integer;
begin
  FCat := TFlatBtn(Sender).Tag;
  for i := 0 to 5 do btnCat[i].Down := i = FCat;
  ApplyFilter;
end;

procedure TMainForm.OnTab(Sender: TObject);
var i, k: Integer;
begin
  k := TFlatBtn(Sender).Tag;
  for i := 0 to 7 do
  begin
    btnTab[i].Down := i = k;
    pages[i].Visible := i = k;
  end;
  if k = 2 then WriteNews;
  if (k = 3) and (Trim(edEntry.Text) = '') then OnCalcSig(nil);
  if k = 3 then DoCalc;
end;

procedure TMainForm.OnSearch(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TMainForm.OnSort(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TMainForm.OnRefresh(Sender: TObject);
begin
  FBusyTick := False;
  LoadTickers;
  LoadMain;
end;

procedure TMainForm.AppMessage(var Msg: TMsg; var Handled: Boolean);
var pt: TPoint; r: TRect; sh: TShiftState;
begin
  if (Msg.message = WM_MOUSEWHEEL) and Assigned(Chart) and Chart.HandleAllocated then
  begin
    GetCursorPos(pt);
    r.TopLeft := Chart.ClientToScreen(Point(0, 0));
    r.BottomRight := Chart.ClientToScreen(Point(Chart.ClientWidth, Chart.ClientHeight));
    if PtInRect(r, pt) then
    begin
      sh := [];
      if GetKeyState(VK_CONTROL) < 0 then Include(sh, ssCtrl);
      if GetKeyState(VK_SHIFT) < 0 then Include(sh, ssShift);
      Chart.Wheel(SmallInt(HiWord(Msg.wParam)), sh);
      Handled := True;
    end;
  end;
end;

{ ---------------- Kalkulator ---------------- }

procedure TMainForm.OnCalcDir(Sender: TObject);
begin
  FCalcDir := TFlatBtn(Sender).Tag;
  btnBuyCalc.Down := FCalcDir = 1;
  btnSellCalc.Down := FCalcDir = -1;
  DoCalc;
end;

procedure TMainForm.OnCalcNow(Sender: TObject);
var n: Integer;
begin
  n := Length(FCandles);
  if n = 0 then Exit;
  edEntry.Text := FmtP(FCandles[n - 1].C, PriceDigits);
  DoCalc;
end;

procedure TMainForm.OnCalcSig(Sender: TObject);
begin
  if FSig.Entry <= 0 then Exit;
  edEntry.Text := FmtP(FSig.Entry, PriceDigits);
  edSL.Text := FmtP(FSig.SL, PriceDigits);
  edTP.Text := FmtP(FSig.TP1, PriceDigits);
  if FSig.Score >= 0 then OnCalcDir(btnBuyCalc) else OnCalcDir(btnSellCalc);
end;

procedure TMainForm.OnCalcBtn(Sender: TObject);
begin
  DoCalc;
end;

procedure TMainForm.OnLotStep(Sender: TObject);
var lot: Double;
begin
  lot := PF(StringReplace(edLot.Text, ',', '.', [])) + TFlatBtn(Sender).Tag * 0.01;
  if lot < 0.01 then lot := 0.01;
  edLot.Text := FormatFloat('0.00', lot);
  DoCalc;
end;

procedure TMainForm.OnLotRek(Sender: TObject);
begin
  DoCalc;
  if FCalcAutoLot >= 0.01 then
  begin
    edLot.Text := FormatFloat('0.00', FCalcAutoLot);
    DoCalc;
  end;
end;

procedure TMainForm.DoCalc;
const PipXAU = 0.1; PipVal = 10.0; { USD per pip per 1 lot (100 oz) }
  LotTab: array[0..7] of Double = (0.01, 0.02, 0.03, 0.05, 0.10, 0.20, 0.50, 1.00);
var R: TRichEdit; bal, rk, en, sl, tp, lev, lot, slp, tpp, riskUsd, autoLot, mv, need, L: Double;
    hasSL, inTab: Boolean; i, n: Integer;

  procedure RuinRow(L: Double; Mark: Boolean);
  var m: Double;
  begin
    m := bal / (L * 100);
    REL(R, Format('%s %5s  %9s pips  %10s  %10s  %9s', [Sx(Mark, '>', ' '), FormatFloat('0.00', L),
      FormatFloat('#,##0', m / PipXAU), FmtP(Max(en - m, 0), 2), FmtP(en + m, 2),
      '$' + FormatFloat('#,##0.00', L * PipVal)]), Cx(Mark, clrYellow, clrText), Mark, 8, 'Consolas');
  end;

begin
  R := reCalc;
  REBegin(R);
  bal := PF(StringReplace(edBal.Text, ',', '.', [])); rk := PF(StringReplace(edRisk.Text, ',', '.', []));
  en := PF(StringReplace(edEntry.Text, ',', '.', [])); sl := PF(StringReplace(edSL.Text, ',', '.', []));
  tp := PF(StringReplace(edTP.Text, ',', '.', [])); lev := PF(edLev.Text); lot := PF(StringReplace(edLot.Text, ',', '.', []));
  n := Length(FCandles);
  if (en <= 0) and (n > 0) then en := FCandles[n - 1].C;
  FCalcAutoLot := 0;
  if (bal <= 0) or (en <= 0) then
  begin
    REL(R, 'Isi saldo dan harga entry. Gunakan tombol "Harga kini" atau "Dari sinyal".', clrMuted);
    REH(R, 'TABEL NILAI PIP XAUUSD');
    REL(R, '  0.01 lot = $0.10 / pip   ' + #149 + '  10 pips = $1', clrText);
    REL(R, '  0.10 lot = $1.00 / pip   ' + #149 + '  10 pips = $10', clrText);
    REL(R, '  1.00 lot = $10.00 / pip  ' + #149 + '  10 pips = $100', clrText);
    REL(R, '  Pergerakan harga $1.00 (mis. 4000 -> 4001) = 10 pips', clrMuted);
    REEnd(R);
    Exit;
  end;
  hasSL := sl > 0;
  slp := 0; tpp := 0; riskUsd := bal * rk / 100; autoLot := 0;
  if hasSL then
  begin
    if ((FCalcDir = 1) and (sl >= en)) or ((FCalcDir = -1) and (sl <= en)) then
      REL(R, 'PERINGATAN: posisi Stop Loss salah arah untuk ' + Sx(FCalcDir = 1, 'BUY (SL harus di bawah entry)', 'SELL (SL harus di atas entry)'), clrRed, True);
    slp := Abs(en - sl) / PipXAU;
    if tp > 0 then tpp := Abs(tp - en) / PipXAU;
    if slp > 0 then autoLot := Floor(riskUsd / (slp * PipVal) * 100) / 100;
    if (slp > 0) and (autoLot < 0.01) then
    begin
      autoLot := 0.01;
      REL(R, Format('Catatan: lot minimum 0.01 berisiko $%s (%.2f%% saldo), melebihi batas risiko Anda.', [FormatFloat('0.00', 0.01 * slp * PipVal), 0.01 * slp * PipVal / bal * 100]), RGB(255, 145, 0), True);
    end;
    FCalcAutoLot := autoLot;
  end;
  if lot <= 0 then lot := Max(autoLot, 0.01);

  REL(R, 'HASIL PERHITUNGAN ' + Sx(FCalcDir = 1, 'BUY', 'SELL') + ' XAU', DirCol(FCalcDir), True, 11);
  REKV(R, '  Modal: ', '$' + FormatFloat('#,##0.00', bal) + '   ' + #149 + '   entry ' + FmtP(en, 2) +
    Sx(Trim(edEntry.Text) = '', ' (harga kini)', ''), clrText);
  REKV(R, '  Lot dipakai: ', FormatFloat('0.00', lot) + ' lot  (' + FormatFloat('0.##', lot * 100) + ' oz)', clrYellow);
  REKV(R, '  Nilai per pip: ', '$' + FormatFloat('0.00', lot * PipVal) + '   ($1 pergerakan harga = $' +
    FormatFloat('#,##0.00', lot * 100) + ')', clrText);
  if lev > 0 then
  begin
    need := lot * 100 * en / lev;
    REKV(R, '  Margin dibutuhkan: ', '$' + FormatFloat('#,##0.00', need) + '  (leverage 1:' + FormatFloat('0', lev) + ')',
      Cx(need > bal, clrRed, clrText));
    if need > bal then
      REL(R, '  SALDO TIDAK CUKUP untuk membuka ' + FormatFloat('0.00', lot) + ' lot - kecilkan lot atau tambah modal.', clrRed, True);
  end;
  if hasSL then
  begin
    REKV(R, '  Jarak Stop Loss: ', FormatFloat('0.0', slp) + ' pips  ($' + FormatFloat('0.00', Abs(en - sl)) + ' pergerakan harga)', clrRed);
    if tpp > 0 then
    begin
      REKV(R, '  Jarak Take Profit: ', FormatFloat('0.0', tpp) + ' pips', clrGreen);
      REKV(R, '  Risk : Reward: ', '1 : ' + FormatFloat('0.00', tpp / Max(slp, 0.0001)) + Sx(tpp / Max(slp, 0.0001) >= 2, '  (BAGUS >= 1:2)', '  (kurang dari 1:2!)'),
        Cx(tpp / Max(slp, 0.0001) >= 2, clrGreen, clrRed));
    end;
    REKV(R, '  Risiko maksimal: ', '$' + FormatFloat('#,##0.00', riskUsd) + ' (' + FormatFloat('0.##', rk) + '% saldo)', clrText);
    REKV(R, '  LOT REKOMENDASI: ', FormatFloat('0.00', autoLot) + ' lot  (tombol "Rekom.")', clrYellow);
    REKV(R, '  Rugi jika kena SL: ', '-$' + FormatFloat('#,##0.00', lot * slp * PipVal) +
      Format('  (%.2f%% saldo)', [lot * slp * PipVal / bal * 100]), clrRed);
    if tpp > 0 then
      REKV(R, '  Untung jika kena TP: ', '+$' + FormatFloat('#,##0.00', lot * tpp * PipVal) +
        Format('  (%.2f%% saldo)', [lot * tpp * PipVal / bal * 100]), clrGreen);
  end;

  { modal habis: rugi = saldo  ->  pergerakan harga = saldo / (lot x 100 oz) }
  mv := bal / (lot * 100);
  REH(R, 'MODAL HABIS DI HARGA BERAPA?');
  REKV(R, '  Modal $' + FormatFloat('#,##0', bal) + ' dengan ' + FormatFloat('0.00', lot) + ' lot habis setelah: ',
    FormatFloat('#,##0', mv / PipXAU) + ' pips  ($' + FormatFloat('#,##0.00', mv) + ' pergerakan harga)', clrRed);
  REKV(R, '  ' + Sx(FCalcDir = 1, 'BUY habis bila harga TURUN ke: ', 'SELL habis bila harga NAIK ke: '),
    FmtP(Max(en - FCalcDir * mv, 0), 2), clrRed);
  REKV(R, '  ' + Sx(FCalcDir = 1, '(bila SELL, habis bila harga naik ke ', '(bila BUY, habis bila harga turun ke '),
    FmtP(Max(en + FCalcDir * mv, 0), 2) + ')', clrMuted);
  if hasSL and (slp > 0) then
  begin
    if slp >= mv / PipXAU then
      REL(R, '  BAHAYA: Stop Loss lebih jauh dari batas modal - akun habis sebelum SL tersentuh!', clrRed, True)
    else
      REL(R, Format('  Stop Loss memakai %.1f%% dari jarak modal habis.', [slp / (mv / PipXAU) * 100]),
        Cx(slp / (mv / PipXAU) > 0.05, RGB(255, 145, 0), clrGreen));
  end;
  REL(R, '', clrText, False, 4);
  REL(R, '  Lot    Habis setelah    BUY habis   SELL habis   per pip', clrMuted, True, 8, 'Consolas');
  inTab := False;
  for i := 0 to High(LotTab) do
  begin
    L := LotTab[i];
    if (not inTab) and (lot < L - 0.0001) then begin RuinRow(lot, True); inTab := True; end;
    if Abs(L - lot) < 0.0001 then inTab := True;
    RuinRow(L, Abs(L - lot) < 0.0001);
  end;
  if not inTab then RuinRow(lot, True);
  REL(R, '', clrText, False, 4);
  REL(R, 'Exness Standard: stop out 0% = posisi ditutup paksa saat ekuitas habis. Belum termasuk spread, ' +
    'swap & komisi, jadi dalam praktik modal habis sedikit lebih cepat.', clrMuted);
  REL(R, 'Rumus: pips = selisih harga / 0.10;  profit = lot x pips x $10;  habis = modal / (lot x 100)', clrMuted);
  REEnd(R);
end;

end.
