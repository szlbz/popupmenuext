unit PopupMenuExt;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Menus, LCLType, LCLIntf, Controls, Forms,
  StdCtrls, ExtCtrls, Math, LMessages, ImgList, LCLProc, Types; // 添加 Types 单元

const
  My_IconSize = 24;

type
  TPopupMenuStyle = record
    FontName: String;
    FontSize: Integer;
    FontColor: TColor;
    BgColor: TColor;
    SelectedFontColor: TColor;
    SelectedBgColor: TColor;
    DisabledFontColor: TColor;
    SeparatorColor: TColor;
    ItemPadding: Integer;
    IconSize: Integer;
  end;
  PPopupMenuStyle = ^TPopupMenuStyle;

  TPopupMenu = class;

  // 统一的模拟弹出窗口
  TSimulatedPopupForm = class(TCustomForm)
  private
    FStyle: PPopupMenuStyle;
    FMenuItems: TList;
    FItemRects: array of TRect;
    FSelectedIndex: Integer;
    FRootMenu: TPopupMenu;
    FParentPopup: TSimulatedPopupForm;
    FChildPopup: TSimulatedPopupForm;
    FImageList: TCustomImageList;

    procedure SetStyle(AValue: PPopupMenuStyle);
    procedure CalculateSizes;
    procedure DrawMenu;
    procedure SetSelectedIndex(Index: Integer);
    procedure CMMouseLeave(var Message: TLMessage); message CM_MOUSELEAVE;
    procedure ShowSubMenu(Index: Integer);
    procedure CloseChain;
    function GetImageList: TCustomImageList;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoShow; override;
    procedure Deactivate; override;
    // 增加键盘支持 (Esc 关闭)
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;

    procedure Popup(AX, AY: Integer; AMenu: TPopupMenu); overload;
    procedure Popup(AX, AY: Integer; AItem: TMenuItem; AParent: TSimulatedPopupForm); overload;

    property Style: PPopupMenuStyle read FStyle write SetStyle;
  end;

  // 菜单拦截器
  TPopupMenu = class(Menus.TPopupMenu)
  private
    procedure SetStylePtr(Value: PPopupMenuStyle);
    function GetStylePtr: PPopupMenuStyle;
  protected
    procedure Popup(X, Y: Integer); override;
  public
    procedure ApplyStyle(Style: PPopupMenuStyle);
    property StylePtr: PPopupMenuStyle read GetStylePtr write SetStylePtr;
  end;

function DefaultMenuStyle: TPopupMenuStyle;

implementation

var
  GStyleList: TList;

type
  TMenuStyleLink = class
    Menu: TPopupMenu;
    Style: PPopupMenuStyle;
  end;

function DefaultMenuStyle: TPopupMenuStyle;
begin
  Result.FontName := 'default';
  Result.FontSize := 10;
  Result.FontColor := clBlack;
  Result.BgColor := clWhite;
  Result.SelectedFontColor := clWhite;
  Result.SelectedBgColor := clHighlight;
  Result.DisabledFontColor := clGray;
  Result.SeparatorColor := clSilver;
  Result.ItemPadding := 4;
  Result.IconSize := My_IconSize;
end;

function GetStyleForMenu(AMenu: TPopupMenu): PPopupMenuStyle;
var
  i: Integer;
  Link: TMenuStyleLink;
begin
  Result := nil;
  if not Assigned(GStyleList) then Exit;
  for i := 0 to GStyleList.Count - 1 do
  begin
    Link := TMenuStyleLink(GStyleList[i]);
    if Link.Menu = AMenu then Exit(Link.Style);
  end;
end;

procedure RegisterStyle(AMenu: TPopupMenu; AStyle: PPopupMenuStyle);
var
  Link: TMenuStyleLink;
  i: Integer;
begin
  if not Assigned(GStyleList) then GStyleList := TList.Create;
  for i := GStyleList.Count - 1 downto 0 do
  begin
    Link := TMenuStyleLink(GStyleList[i]);
    if Link.Menu = AMenu then begin GStyleList.Delete(i); Link.Free; end;
  end;
  Link := TMenuStyleLink.Create;
  Link.Menu := AMenu;
  Link.Style := AStyle;
  GStyleList.Add(Link);
end;

{ TSimulatedPopupForm (Windows & Linux Unified) }

constructor TSimulatedPopupForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  FMenuItems := TList.Create;
  FSelectedIndex := -1;
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  ControlStyle := ControlStyle + [csOpaque]; // 防止闪烁

  // 设置 KeyPreview 以捕获键盘事件
  KeyPreview := True;
end;

destructor TSimulatedPopupForm.Destroy;
begin
  if Assigned(FParentPopup) then FParentPopup.FChildPopup := nil;
  if Assigned(FChildPopup) then FreeAndNil(FChildPopup);

  FMenuItems.Free;
  inherited Destroy;
end;

procedure TSimulatedPopupForm.SetStyle(AValue: PPopupMenuStyle);
begin
  FStyle := AValue;
  if Assigned(FStyle) then Color := FStyle^.BgColor;
end;

function TSimulatedPopupForm.GetImageList: TCustomImageList;
begin
  if Assigned(FRootMenu) then Result := FRootMenu.Images
  else Result := nil;
end;

procedure TSimulatedPopupForm.DoShow;
begin
  inherited DoShow;
  SetFocus;
end;

procedure TSimulatedPopupForm.Deactivate;
begin
  inherited Deactivate;
  // 如果点击了其他程序，关闭菜单链
  if Assigned(FChildPopup) and FChildPopup.Visible then Exit;
  CloseChain;
end;

procedure TSimulatedPopupForm.CloseChain;
begin
  if Assigned(FChildPopup) then
  begin
    FChildPopup.CloseChain;
    FreeAndNil(FChildPopup);
  end;
  Close;
end;

// 键盘事件处理：Esc 关闭
procedure TSimulatedPopupForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Key = VK_ESCAPE then
  begin
    CloseChain;
    Key := 0;
  end;
end;

procedure TSimulatedPopupForm.Popup(AX, AY: Integer; AMenu: TPopupMenu);
var
  i: Integer;
begin
  FRootMenu := AMenu;
  FParentPopup := nil;
  FMenuItems.Clear;
  for i := 0 to AMenu.Items.Count - 1 do FMenuItems.Add(AMenu.Items[i]);
  FImageList := AMenu.Images;

  CalculateSizes;

  // 屏幕边界修正
  if AX + Width > Screen.Width then AX := Screen.Width - Width;
  if AY + Height > Screen.Height then AY := Screen.Height - Height;

  Left := AX; Top := AY;
  Show;
end;

procedure TSimulatedPopupForm.Popup(AX, AY: Integer; AItem: TMenuItem; AParent: TSimulatedPopupForm);
var
  i: Integer;
begin
  FRootMenu := AParent.FRootMenu;
  FParentPopup := AParent;
  AParent.FChildPopup := Self;

  FMenuItems.Clear;
  for i := 0 to AItem.Count - 1 do FMenuItems.Add(AItem.Items[i]);
  FImageList := FRootMenu.Images;

  CalculateSizes;

  // 屏幕边界修正
  if AX + Width > Screen.Width then AX := AParent.Left - Width; // 如果右边放不下，放左边
  if AY + Height > Screen.Height then AY := Screen.Height - Height;

  Left := AX; Top := AY;
  Show;
end;

procedure TSimulatedPopupForm.CalculateSizes;
var
  i: Integer;
  Item: TMenuItem;
  H, MaxW, CurW: Integer;
  R: TRect;
  S: String;
begin
  if not Assigned(FStyle) then Exit;
  Canvas.Font.Name := FStyle^.FontName;
  Canvas.Font.Size := FStyle^.FontSize;

  SetLength(FItemRects, FMenuItems.Count);
  MaxW := 150; // 初始最小宽度

  // 1. 计算最大宽度
  for i := 0 to FMenuItems.Count - 1 do
  begin
    Item := TMenuItem(FMenuItems[i]);
    if Item.IsLine then Continue;

    // 基础宽度 = 图标 + 间距
    CurW := FStyle^.IconSize + 10;
    // 标题宽度
    CurW := CurW + Canvas.TextWidth(Item.Caption);

    // 快捷键宽度
    if Item.ShortCut <> 0 then
    begin
      S := ShortCutToText(Item.ShortCut);
      CurW := CurW + Canvas.TextWidth(S) + 20;
    end;

    // 子菜单箭头宽度
    if Item.Count > 0 then
      CurW := CurW + 25;

    if CurW > MaxW then MaxW := CurW;
  end;

  // 2. 统一分配矩形区域
  R.Top := 0;
  for i := 0 to FMenuItems.Count - 1 do
  begin
    Item := TMenuItem(FMenuItems[i]);

    if Item.IsLine then H := 6
    else H := Canvas.TextHeight('Wg') + (FStyle^.ItemPadding * 2);

    R.Left := 0;
    R.Right := MaxW; // 统一使用最大宽度
    R.Bottom := R.Top + H;
    FItemRects[i] := R;

    R.Top := R.Bottom;
  end;

  ClientWidth := MaxW;
  ClientHeight := R.Top;
end;

procedure TSimulatedPopupForm.Paint;
begin
  DrawMenu;
end;

procedure TSimulatedPopupForm.DrawMenu;
var
  i: Integer;
  Item: TMenuItem;
  R: TRect;
  IconRect: TRect;
  TargetIconSize: Integer;
  TempBmp: TBitmap;
  ShortCutTxt: String;
  TextY: Integer;
  ArrowSpace: Integer;
  CenterY: Integer; // 用于计算分隔线位置
begin
  if not Assigned(FStyle) then Exit;

  TargetIconSize := FStyle^.IconSize;

  // 绘制背景
  Canvas.Brush.Color := FStyle^.BgColor;
  Canvas.FillRect(ClientRect);

  Canvas.Font.Name := FStyle^.FontName;
  Canvas.Font.Size := FStyle^.FontSize;

  for i := 0 to FMenuItems.Count - 1 do
  begin
    Item := TMenuItem(FMenuItems[i]);
    R := FItemRects[i];

    // 【修改1】：优先判断是否为分隔线
    if Item.IsLine then
    begin
      // 确保分隔线背景色为普通背景色，且不绘制高亮
      Canvas.Brush.Color := FStyle^.BgColor;
      Canvas.FillRect(R);
      Canvas.Pen.Color := FStyle^.SeparatorColor;

      // 计算中心线 Y 坐标，替代 R.CenterPoint.Y
      CenterY := R.Top + (R.Bottom - R.Top) div 2;
      Canvas.Line(R.Left + TargetIconSize + 4, CenterY, R.Right - 2, CenterY);
    end
    else
    begin
      // 绘制高亮背景
      if i = FSelectedIndex then
      begin
        Canvas.Brush.Color := FStyle^.SelectedBgColor;
        Canvas.Font.Color := FStyle^.SelectedFontColor;
        Canvas.FillRect(R);
      end else
      begin
        Canvas.Brush.Color := FStyle^.BgColor;
        if Item.Enabled then Canvas.Font.Color := FStyle^.FontColor
        else Canvas.Font.Color := FStyle^.DisabledFontColor;
      end;

      // 1. 绘制图标 (统一缩放)
      IconRect.Left := R.Left + 2;
      IconRect.Right := IconRect.Left + TargetIconSize;
      IconRect.Top := R.Top + (R.Height - TargetIconSize) div 2;
      IconRect.Bottom := IconRect.Top + TargetIconSize;

      if Assigned(FImageList) and (Item.ImageIndex >= 0) then
      begin
        TempBmp := TBitmap.Create;
        try
          TempBmp.SetSize(TargetIconSize, TargetIconSize);
          TempBmp.Canvas.Brush.Color := FStyle^.BgColor; // 背景色填充
          TempBmp.Canvas.FillRect(0, 0, TargetIconSize, TargetIconSize);
          FImageList.Draw(TempBmp.Canvas, 0, 0, Item.ImageIndex, dsNormal, itImage);
          Canvas.StretchDraw(IconRect, TempBmp);
        finally
          TempBmp.Free;
        end;
      end else if not Item.Bitmap.Empty then
      begin
        Canvas.StretchDraw(IconRect, Item.Bitmap);
      end;

      TextY := R.Top + FStyle^.ItemPadding;

      // 2. 绘制子菜单箭头 (最右侧)
      ArrowSpace := 0;
      if Item.Count > 0 then
      begin
        ArrowSpace := 20;
        Canvas.TextOut(R.Right - 15, TextY, '►');
      end;

      // 3. 绘制快捷键 (右对齐，在箭头左侧)
      if Item.ShortCut <> 0 then
      begin
        ShortCutTxt := ShortCutToText(Item.ShortCut);
        Canvas.TextOut(R.Right - ArrowSpace - Canvas.TextWidth(ShortCutTxt) - 5, TextY, ShortCutTxt);
      end;

      // 4. 绘制标题
      // 使用 TextRect 确保标题过长时不会覆盖右侧的快捷键
      R.Left := TargetIconSize + 6;
      Canvas.TextRect(R, R.Left, TextY, Item.Caption);
    end;
  end;
end;

procedure TSimulatedPopupForm.SetSelectedIndex(Index: Integer);
begin
  if FSelectedIndex <> Index then
  begin
    FSelectedIndex := Index;
    Invalidate;

    if Assigned(FChildPopup) then
    begin
      FChildPopup.Free;
      FChildPopup := nil;
    end;

    if (Index >= 0) then
      ShowSubMenu(Index);
  end;
end;

procedure TSimulatedPopupForm.ShowSubMenu(Index: Integer);
var
  Item: TMenuItem;
  ChildForm: TSimulatedPopupForm;
  P: TPoint;
begin
  Item := TMenuItem(FMenuItems[Index]);
  if (Item.Count = 0) or (not Item.Enabled) then Exit;

  P.X := Left + Width;
  P.Y := Top + FItemRects[Index].Top;

  ChildForm := TSimulatedPopupForm.CreateNew(nil);
  ChildForm.Style := FStyle;
  ChildForm.Popup(P.X, P.Y, Item, Self);
end;

procedure TSimulatedPopupForm.CMMouseLeave(var Message: TLMessage);
begin
  if not (Assigned(FChildPopup) and FChildPopup.Visible) then
    SetSelectedIndex(-1);
  inherited;
end;

procedure TSimulatedPopupForm.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  P: TPoint;
  Item: TMenuItem;
begin
  inherited;
  P := Point(X, Y);
  for i := 0 to High(FItemRects) do
  begin
    if PtInRect(FItemRects[i], P) then
    begin
      Item := TMenuItem(FMenuItems[i]);
      // 【修改2】：如果鼠标悬停在分隔线上，清除选中状态
      if Item.IsLine then
      begin
        SetSelectedIndex(-1);
        Exit;
      end;

      SetSelectedIndex(i);
      Exit;
    end;
  end;
end;

procedure TSimulatedPopupForm.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  P: TPoint;
  Item: TMenuItem;
  Root: TSimulatedPopupForm;
begin
  inherited;
  if Button <> mbLeft then Exit;
  P := Point(X, Y);
  for i := 0 to High(FItemRects) do
  begin
    if PtInRect(FItemRects[i], P) then
    begin
      Item := TMenuItem(FMenuItems[i]);
      if (not Item.IsLine) and Item.Enabled and (Item.Count = 0) then
      begin
        if Assigned(FRootMenu) then FRootMenu.Close;

        Root := Self;
        while Assigned(Root.FParentPopup) do Root := Root.FParentPopup;
        Root.CloseChain;

        Item.Click;
      end;
      Exit;
    end;
  end;
end;

{ TPopupMenu 拦截器 }

procedure TPopupMenu.SetStylePtr(Value: PPopupMenuStyle);
begin
  RegisterStyle(Self, Value);
end;

function TPopupMenu.GetStylePtr: PPopupMenuStyle;
begin
  Result := GetStyleForMenu(Self);
end;

procedure TPopupMenu.ApplyStyle(Style: PPopupMenuStyle);
begin
  StylePtr := Style;
end;

procedure TPopupMenu.Popup(X, Y: Integer);
var
  Frm: TSimulatedPopupForm;
  PStyle: PPopupMenuStyle;
begin
  PStyle := GetStyleForMenu(Self);
  if not Assigned(PStyle) then begin inherited Popup(X, Y); Exit; end;

  Frm := TSimulatedPopupForm.CreateNew(nil);
  Frm.Style := PStyle;
  Frm.Popup(X, Y, Self);
end;

initialization
  GStyleList := TList.Create;

finalization
  while GStyleList.Count > 0 do begin TObject(GStyleList[0]).Free; GStyleList.Delete(0); end;
  GStyleList.Free;

end.

