import 'dart:typed_data';

import 'package:fight_report/Common/AppBackgroundPage.dart';
import 'package:fight_report/Common/DataManager.dart';
import 'package:fight_report/view/FightDetail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:fight_report/Common/Defines.dart' as def;


class MainView extends StatefulWidget {
  @override
  _MainViewState createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {

  // DataBaseHelperをインスタンス化
  final dh = DatabaseHelper.instance;

  List<int> _pointItemsInt = new List.generate(251, (i)=>(1500+i*10));
  List<int> _ticketItemsInt = new List.generate(11, (i)=>(i+1));

  List<String> _pointItems = [];
  List<String> _ticketItems = [];

  @override
  void initState() {
    super.initState();
    for( int i=0; i<_pointItemsInt.length; i++ ){
      _pointItems.add( _formatNum(_pointItemsInt[i]) );
    }
    for( int i=0; i<_ticketItemsInt.length; i++ ){
      _ticketItems.add( _ticketItemsInt[i].toString() );
    }
    _pointItems.insert(0, '');
    _ticketItems.insert(0, '');
  }

  @override
  void dispose() {
    eCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  //テキストフィールド入力チェック用
  bool _validate = false;
  bool _validateEditName = false;

  //レポート削除コーションのオフステージ
  bool _offstageDeleteCaution = true;

  //レポート名編集用画面のオフステージ
  bool _offstageEditReportName = true;

  //レポート削除用のインデックス
  int _deleteReportIndex = 0;

  //レポート名編集用のインデックス
  int _editReportNameIndex = 0;

  String targetPoints = '2,000';
  String numOfTicket = '11';


  //Input fieldで使用するControllerの定義
  final TextEditingController eCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();

  DataManager dm = new DataManager();

  //現在時刻をフォーマット化するための関数を定義
  String _dateTimeFormat( DateTime date ) {
    String formatted;
    formatted = '${date.year}-${date.month}-${date.day}';
    return formatted;
  }

  //３桁ごとにコンマを入れるフォーマットメソッド
  String _formatNum( int num ){
    String _result;
    final formatterInt = NumberFormat("#,###");
    _result = formatterInt.format(num);
    return _result;
  }

  //３桁ごとのコンマを外すフォーマットメソッド
  String _fomatInverse( String formattedNum ){
    String _result;
    _result = formattedNum.replaceFirst(RegExp(','), '');
    return _result;
  }



  //　Validateの後に行われる処理
  // Listに新しいFightDataが追加される処理です。
  void _addReportDataItem(String text) async{

    //##########SQLiteの操作関連ここから################
    //GuildFestReportListのテーブルが作成してなければ、作成する
    //idは1固定、languageの初期値は0(日本語)、reportDataListはnull
    int guildFestReportId;
    Map<String, dynamic> rowGFReportList;
    List<Map<String, dynamic>> tempListMap = await dh.queryAllRows( dh.guildFestReportList );
    if( tempListMap.length == 0 ){
      rowGFReportList = {
        'id' : 1,  // idは必ず1でデータも1つのみでOK
        'language' : 0,
        'reportDataList' : null,  //List<int> = BLOB はUint8List形式で保存しておくこと
      };
      guildFestReportId = await dh.insert( dh.guildFestReportList, rowGFReportList );
    }
    tempListMap = await dh.queryAllRows( dh.guildFestReportList );
    guildFestReportId = tempListMap.first['id'];
    //##########SQLiteの操作関連ここまで################

    _validate = false;
    int quotePoint, quoteTicket;
    if( targetPoints != '' ){
      quotePoint = int.parse( _fomatInverse(targetPoints) );
    } else if( targetPoints == '' ){
      quotePoint = 1500;
    }
    if( numOfTicket != '' ){
      quoteTicket = int.parse(numOfTicket);
    } else if( numOfTicket == '' ){
      quoteTicket = 11;
    }
    DateTime date = new DateTime.now();

    //##########SQLiteの操作関連ここから################
    final ReportData newReportData = ReportData( text, date, quotePoint, quoteTicket );
    dm.addReportData(newReportData); //SQL完了時に削除
    final _dateFormatter = DateFormat("yyyy-MM-dd");
    var formatted = _dateFormatter.format(date); // DateTimeからStringに変換
    Map<String, dynamic> rowReportData = {
      'reportTitle' : text,
      'date' : formatted,
      'quotePoint' : quotePoint,
      'quoteTicket' : quoteTicket,
    };
    final id = await dh.insert( dh.reportData, rowReportData );
    //追加したIDをGuildFestReportListのテーブルの０番目に追加する
    List<int> reportList;
    var reportUint8List = tempListMap.first['reportDataList'];
    if( reportUint8List == null ){
      reportList = [];
    } else {
      reportList = List.from( reportUint8List );
    }
    reportList.insert( 0, id );
    rowGFReportList = {
      'id' : 1,  // idは必ず1でデータも1つのみでOK
      'reportDataList' : Uint8List.fromList( reportList ),  //List<int> = BLOB はUint8List形式で保存しておくこと
    };
    dh.update( dh.guildFestReportList, rowGFReportList );
    //##########SQLiteの操作関連ここまで################

    // Controllerの内容を消去する
    eCtrl.clear();
    // SetStateを行うことによってWidgetの内容を更新
    setState(() {});
  }

  void _duplicateReportDataItem( List<ReportData> rdl, int index ){

    //新しいFightDataを作成する
    int quotePoint, quoteTicket;
    String text = '${rdl[index].reportTitle} - copy';
    if( targetPoints != '' ){
      quotePoint = int.parse( _fomatInverse(targetPoints) );
    } else if( targetPoints == '' ){
      quotePoint = 1500;
    }
    if( numOfTicket != '' ){
      quoteTicket = int.parse(numOfTicket);
    } else if( numOfTicket == '' ){
      quoteTicket = 11;
    }
    DateTime date = new DateTime.now();
    final ReportData newReportData = ReportData( text, date, quotePoint, quoteTicket );
    dm.addReportData(newReportData);

    //プレイヤー名をコピーする処理
    //rklにはすでにコピーが追加されているので、index -> index+1　となることに注意
    String playerName;
    for( int i=0; i<rdl[index+1].playerDataList.length; i++ ){
      //プレイヤー追加の処理　プレイヤー名をコピーする
      playerName = rdl[index+1].playerDataList[i].playerName;
      quoteTicket = rdl[index+1].quoteTicket;
      final PlayerData newPlayerData = PlayerData( playerName, quoteTicket );
      for( int i=0; i<3; i++ ){
        newPlayerData.bonusQuest.add('');
      }
      for( int i=0; i<quoteTicket; i++ ){
        final QuestData newQuestData = QuestData();
        newPlayerData.questDataList.add( newQuestData );
      }
      newReportData.playerDataList.add(newPlayerData);
    }

  }

  void _removeReportDataItem( ReportData rd ){
    setState(() {
      dm.removeReportData( rd );
      setDeleteIndex(0);
    });
  }

  void _showModalPicker(BuildContext context, List<String> items) {
    String initialItem;
    if( items == _pointItems ){
      initialItem = targetPoints;
    }
    if( items == _ticketItems ){
      initialItem = numOfTicket;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height *0.5,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: CupertinoPicker(
              itemExtent: 40,
              children: items.map(_pickerItem).toList(),
              onSelectedItemChanged: (index) => _onSelectedItemChanged(items, index),
              scrollController: FixedExtentScrollController(
                initialItem: items.indexOf(initialItem),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pickerItem(String str) {
    return Text(
      str,
      style: const TextStyle(fontSize: 32),
    );
  }

  void _onSelectedItemChanged(List<String> items, int index) {
    setState(() {
      if( items == _pointItems ){
        targetPoints = items[index];
      }
      if( items == _ticketItems ){
        numOfTicket = items[index];
      }
    });
  }

  void setEditIndex( int index ){
    _editReportNameIndex = index;
  }

  void setDeleteIndex( int index ){
    _deleteReportIndex = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(def.Word().title[dm.language]),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          AppBackgroundPage(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        children: [

                          /////////////////////////デバッグ用///////////////////////////////
                          FlatButton(
                              onPressed: ()async{
                                dh.delete(dh.guildFestReportList);
                                dh.delete(dh.reportData);
                                List<Map<String, dynamic>> tempListMap1 = await dh.queryAllRows( dh.guildFestReportList );
                                List<Map<String, dynamic>> tempListMap2 = await dh.queryAllRows( dh.reportData );
                                print( 'GuildFestReportList : ${tempListMap1.length}' );
                                print( 'ReportData : ${tempListMap2.length}' );
                              },
                              child: Text('delete'),
                          ),
                          ////////////////////////////////////////////////////////

                          Container(
                            padding: EdgeInsets.only( left: 8 ),
                            child: Row(
                              children: [
                                Container(
                                  child: FlatButton.icon(
                                    icon: Icon(
                                      dm.language == def.Language().jp
                                          ? Icons.check_box_outlined
                                          : Icons.check_box_outline_blank,
                                      color: Colors.black,
                                    ),
                                    label: Text('日本語'),
                                    textColor: Colors.black,
                                    onPressed: () {
                                      setState(() {
                                        dm.setLanguage( def.Language().jp );
                                      });
                                    },
                                  ),
                                ),
                                Container(
                                  child: FlatButton.icon(
                                    icon: Icon(
                                      dm.language == def.Language().eng
                                          ? Icons.check_box_outlined
                                          : Icons.check_box_outline_blank,
                                      color: Colors.black,
                                    ),
                                    label: Text('English'),
                                    textColor: Colors.black,
                                    onPressed: () {
                                      setState(() {
                                        dm.setLanguage( def.Language().eng );
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Row(
                                  //目標の入力　ドラムロール
                                  children: [
                                    Container(
                                      height: MediaQuery.of(context).size.height * 0.15,
                                      width: MediaQuery.of(context).size.width * 0.1,
                                      child: RaisedButton(
                                        color: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.horizontal(left: Radius.circular(8.0)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              def.Word().point1[dm.language],
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: MediaQuery.of(context).size.height * 0.025,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                            Icon(
                                              Icons.edit_outlined,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                        onPressed: () {
                                          _showModalPicker(context, _pointItems);
                                        },
                                      ),
                                    ),
                                    GestureDetector(
                                      child: Container(
                                        width: MediaQuery.of(context).size.width * 0.12,
                                        height: MediaQuery.of(context).size.height * 0.15,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.horizontal(
                                              right: Radius.circular(8.0)
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            targetPoints,
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context).size.height * 0.06,
                                            ),
                                          ),
                                        ),
                                      ),
                                      onTap: (){
                                        _showModalPicker(context, _pointItems);
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  //チケット枚数の入力　ドラムロール
                                  children: [
                                    Container(
                                      height: MediaQuery.of(context).size.height * 0.15,
                                      width: MediaQuery.of(context).size.width * 0.1,
                                      child: RaisedButton(
                                        color: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.horizontal(left: Radius.circular(8.0)),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              def.Word().ticket1[dm.language],
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: MediaQuery.of(context).size.height * 0.025,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                            Icon(
                                              Icons.edit_outlined,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                        onPressed: () {
                                          _showModalPicker(context, _ticketItems);
                                        },
                                      ),
                                    ),
                                    GestureDetector(
                                      child: Container(
                                        width: MediaQuery.of(context).size.width * 0.10,
                                        height: MediaQuery.of(context).size.height * 0.15,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.horizontal(
                                              right: Radius.circular(8.0)
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            numOfTicket,
                                            style: TextStyle(
                                              fontSize: MediaQuery.of(context).size.height * 0.06,
                                            ),
                                          ),
                                        ),
                                      ),
                                      onTap: (){
                                        _showModalPicker(context, _ticketItems);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            //レポートの新規作成
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(8.0),
                                    height: MediaQuery.of(context).size.height * 0.15,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.horizontal(
                                            left: Radius.circular(8.0)
                                        ),
                                    ),
                                    child: TextField(
                                      //事前に宣言していたTextEditingController(eCtrl）をcontrollerに代入します。
                                      controller: eCtrl,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: def.Word().hintText[dm.language],
                                        errorText: _validate ? def.Word().errorText[dm.language] : null,
                                        contentPadding: EdgeInsets.all(8),
                                      ),
                                      onTap: () => setState(() => _validate = false),
                                      //Keyboardの官僚が押された際にアイテムを追加します。
                                      // 必要なければ省略しても構いません。
                                      onSubmitted: (text) {
                                        //controllerが空のときに、addListItemの処理を行わないように分岐を書きます
                                        if (text.isEmpty) {
                                          setState(() {
                                            _validate = true;
                                          });
                                        } else {
                                          _addReportDataItem(text);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                Container(
                                  height: MediaQuery.of(context).size.height * 0.15,
                                  width: MediaQuery.of(context).size.width * 0.1,
                                  child: RaisedButton(
                                    color: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.horizontal(right: Radius.circular(8.0)),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.add, color: Colors.white),
                                    ),
                                    onPressed: () {
                                      //controllerが空のときに、addListItemの処理を行わないように分岐を書きます
                                      if (eCtrl.text.isEmpty) {
                                        setState(() => _validate = true);
                                      } else {
                                        _addReportDataItem(eCtrl.text);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Offstage(
                      offstage: _offstageEditReportName,
                      child: GestureDetector(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey.withOpacity(0.8),
                        ),
                        onTap: (){
                          setState(() {
                            _offstageEditReportName = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: double.infinity,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      (){
                      return Container();
                      }(),
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: ListView.builder(
                            itemCount: dm.guildFestReportList.length,
                            itemBuilder: (BuildContext context, int fightDataIndex){
                              return _buildListItem( dm.guildFestReportList, fightDataIndex );
                            }
                        ),
                      ),
                      _editReportName( dm.guildFestReportList, _editReportNameIndex ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          dm.guildFestReportList.length == 0
              ?  Container()
              : _caution( dm.guildFestReportList[_deleteReportIndex] ),
        ],
      ),
    );
  }

  Container _buildListItem(List<ReportData> reportDataList, int index) {
    return Container(
      child: Column(
        children: [
          Dismissible(
              key: ObjectKey(reportDataList[index]),
              child: Slidable(
                actionExtentRatio: 0.18,
                actionPane: SlidableDrawerActionPane(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey,
                        width: 1,
                      ),
                    ),
                  ),
                  height: MediaQuery.of(context).size.height * 0.15,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          child: RichText(
                            text : TextSpan(
                              text: reportDataList[index].reportTitle,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: (){
                            Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => FightDetail(reportDataList[index]) )
                            );
                          },
                        ),
                      ),
                      RichText(
                        text : TextSpan(
                          text: _dateTimeFormat(reportDataList[index].date),
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                //右にスライドした時
                actions: [
                  IconSlideAction(
                    caption: def.Word().duplicate[dm.language],
                    color: Colors.grey[200].withOpacity(0.0),
                    icon: Icons.copy,
                    onTap: () {
                      //レポートをコピーするときの処理
                      setState(() {
                        _duplicateReportDataItem( reportDataList, index );
                      });
                    },
                  ),
                  IconSlideAction(
                    caption: def.Word().rename[dm.language],
                    color: Colors.grey[200].withOpacity(0.0),
                    icon: Icons.edit_outlined,
                    onTap: () {
                      setState(() {
                        setEditIndex(index);
                        //レポート名編集用のテキストフィールドに初期値（もともとのレポート名）を設定
                        nameCtrl = TextEditingController(
                          text: reportDataList[index].reportTitle,
                        );
                        _offstageEditReportName = false;
                      });
                    },
                  ),
                ],

                //左にスライドした時
                secondaryActions: [
                  IconSlideAction(
                    caption: def.Word().delete[dm.language],
                    color: Colors.red,
                    icon: Icons.delete,
                    onTap: () {
                      setState(() {
                        setDeleteIndex(index);
                        _offstageDeleteCaution = false;
                      });
                    },
                  )
                ],
              ),
          ),
          reportDataList.length != index+1
              ? Container()
              : Text(
            '<-----${def.Word().slideGuide1[dm.language]}----->',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Offstage _editReportName( List<ReportData> reportDataList, int editReportNameIndex ){
    return Offstage(
      offstage: _offstageEditReportName,
      child: GestureDetector(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey.withOpacity(0.8),
          //レポート編集する時のテキストフィールド
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.only( left: 8, bottom: 4 ),
                alignment: Alignment.bottomLeft,
                child: Text(
                  def.Word().editReportName[dm.language],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      height: MediaQuery.of(context).size.height * 0.15,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(8.0)
                        ),
                      ),
                      child: TextField(
                        //事前に宣言していたTextEditingController(nameCtrl）をcontrollerに代入します。
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: null,
                          errorText: _validateEditName ? def.Word().reportNameIsEmpty[dm.language] : null,
                          contentPadding: EdgeInsets.all(8),
                        ),
                        onTap: () => setState(() => _validateEditName = false),
                        //Keyboardの官僚が押された際にアイテムを追加します。
                        // 必要なければ省略しても構いません。
                        onSubmitted: (reportName) {
                          //controllerが空のときに、addListItemの処理を行わないように分岐を書きます
                          if (reportName.isEmpty) {
                            setState(() {
                              _validateEditName = true;
                            });
                          } else {
                            //入力完了時の処理
                            setState(() {
                              reportDataList[editReportNameIndex].updateReportData('reportTitle', reportName);
                              _offstageEditReportName = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.15,
                    width: MediaQuery.of(context).size.width * 0.1,
                    child: RaisedButton(
                      color: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.horizontal(right: Radius.circular(8.0)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.check, color: Colors.white),
                      ),
                      onPressed: () {
                        //controllerが空のときに、addListItemの処理を行わないように分岐を書きます
                        if (nameCtrl.text.isEmpty) {
                          setState(() => _validateEditName = true);
                        } else {
                          //入力完了時の処理
                          setState(() {
                            reportDataList[editReportNameIndex].updateReportData('reportTitle', nameCtrl.text);
                            _offstageEditReportName = true;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        onTap: (){
          setState(() {
            _offstageEditReportName = true;
          });
        },
      ),
    );
  }

  Offstage _caution( ReportData rd ){
    return Offstage(
      offstage: _offstageDeleteCaution,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    '${def.Word().caution1[dm.language]}${rd.reportTitle}${def.Word().caution2[dm.language]}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    def.Word().caution3[dm.language],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              Container(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RaisedButton(
                    elevation: 16,
                    child: Text( def.Word().caution4[dm.language] ),
                    color: Colors.grey[300],
                    onPressed: () {
                      setState(() {
                        _removeReportDataItem( rd );
                        _offstageDeleteCaution = true;
                      });
                    },
                  ),
                  Container(
                    width: 20,
                  ),
                  RaisedButton(
                    elevation: 16,
                    child: Text( def.Word().caution5[dm.language] ),
                    color: Colors.grey[300],
                    onPressed: () {
                      setState(() {
                        _offstageDeleteCaution = true;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
