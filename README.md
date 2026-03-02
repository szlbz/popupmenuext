# PopupMenu自绘
lazarus在linux采用系统原生的PopupMenu，用户无法设定PopupMenu颜色等参数  
在银河麒麟使用系统原生的popmenu:  
<img width="810" height="675" alt="图片" src="https://github.com/user-attachments/assets/f159c8ed-cbd7-4011-b380-8806c35c614e" />  
使用扩展功能后：  
<img width="804" height="664" alt="图片" src="https://github.com/user-attachments/assets/09eb81ff-00bf-474a-8eda-294cbbd98f4f" />  
  
Demo: 
```pascal
unit menu_unit;

{$mode objfpc}{$H+}
interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, clipbrd,
  Menus, Messages, Buttons, ExtCtrls, ComCtrls, MATH, Spin, CheckLst, LazUTF8,
  LazUtils, cp936, LConvEncoding, LazUnicode, LazUTF16, LazSysUtils,
  LazUtilities, Types, Grids, StyledMenuUnit, PopupMenuExt;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Label1: TLabel;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    Separator2: TMenuItem;
    Separator1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    Panel1: TPanel;
    PopupMenu1: TPopupMenu;
    procedure FormCreate(Sender: TObject);
  private
    FStyleBar:TStyledMenuBar;
    MyMenuStyle: TPopupMenuStyle;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin

  FStyleBar:=TStyledMenuBar.Create(Self);
  FStyleBar.parent:=Self;
  //FStyleBar.Align:=alBottom;// alTop;
  FStyleBar.BarColor:=$00F8E7DA;//clSkyblue;
  FStyleBar.MainMenu:=MainMenu1;
  //FStyleBar.TextColor:=clBlack;
  FStyleBar.ItemHoverColor:=clhighlight;
  FStyleBar.TextHoverColor:=clYellow;
  FStyleBar.PopupColor:=$00F8E7DA;//clGreen;
  //FStyleBar.IconSize:=24;
  FStyleBar.Font.Size := 10;
  FStyleBar.Font.Name := '微软雅黑';

  // 1. 配置样式
  MyMenuStyle := DefaultMenuStyle; // 获取默认值

  MyMenuStyle.FontName := 'Microsoft YaHei'; // 微软雅黑，Linux下如无此字体会自动降级
  MyMenuStyle.FontSize := 10;                // 字体变大
  MyMenuStyle.FontColor := clBlack;
  MyMenuStyle.BgColor :=  $00F0F0F0;          // 浅灰背景
  MyMenuStyle.SelectedBgColor := $00FFCC00;  // 选中时背景
  MyMenuStyle.SelectedFontColor := clBlack;  // 选中时黑色字体
  MyMenuStyle.ItemPadding := 6;              // 增加垂直间距

  // 2. 应用样式到 PopupMenu1
  PopupMenu1.ApplyStyle(@MyMenuStyle);

end;

end.
```
