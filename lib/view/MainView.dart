import 'dart:convert';
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

    //最初にデータベースがなければ作成する処理
    Future(() async{
      Map<String, dynamic> rowGFReportList;
      List<Map<String, dynamic>> tempListMap = await dh.queryAllRows( dh.guildFestReportList );
      if( tempListMap.length == 0 ){
        rowGFReportList = {
          'id' : 1,  // idは必ず1でデータも1つのみでOK
          'language' : 0,
          'reportDataList' : null,  //List<int>はjsonEncodeしてString形式で保存しておくこと
        };
        await dh.insert( dh.guildFestReportList, rowGFReportList );
      }
    });

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

  Future<int> _getLanguage() async{
    int language;
    Map<String, dynamic> tmpMap = await dh.queryOnlyRows( dh.guildFestReportList, 1);
    language = tmpMap['language'];
    return language;
  }

  Future<List<ReportData>> _getReportDataItem() async{
    //まずはレポートIDのリストを取得する
    List<ReportData> reportDataList = [];
    Map<String, dynamic> tmpMap = await dh.queryOnlyRows( dh.guildFestReportList, 1);
    var reportDataIdJsonList = tmpMap['reportDataList'];
    List<int> reportDataIdList = jsonDecode( reportDataIdJsonList ).cast<int>();

    //レポートIDに紐づけられたレポートデータを取得する
    for( int i=0; i<reportDataIdList.length; i++ ){
      Map<String, dynamic> tmp = await dh.queryOnlyRows( dh.reportData, reportDataIdList[i] );
      ReportData rd = ReportData(
        tmp['reportTitle'],
        DateTime.parse( tmp['date'] ),
        tmp['quotePoint'],
        tmp['quoteTicket'],
        tmp['sumPoint'],
        tmp['sumRemainingPoint'],
        tmp['sumConsumedTicket'],
        tmp['sumRemainingTicket'],
        tmp['sumIncompleteTicket'],
        double.parse(tmp['necessaryPoint']),
        double.parse(tmp['necessaryPointBP']),
        null, //playerDataは、この時点ではオブジェクト化せず、tempListにIDリストの形で置いておく
        tmp['playerDataList']==null ? null : jsonDecode( tmp['playerDataList'] ).cast<int>(),
      );
      reportDataList.add( rd );
    }
    return reportDataList;
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
        'reportDataList' : null,  //List<int>はjsonEncodeしてString形式で保存しておくこと
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
      'sumPoint' : 0,
      'sumRemainingPoint' : 0,
      'sumConsumedTicket' : 0,
      'sumRemainingTicket' : 0,
      'sumIncompleteTicket' : 0,
      'necessaryPoint' : '0.0', //double型はSQLite対応してないのでStringとして持つ
      'necessaryPointBP' : '0.0', //double型はSQLite対応してないのでStringとして持つ
      //'playerDataList' : null, //これは↓でupdateするので不要
    };
    final id = await dh.insert( dh.reportData, rowReportData );
    //追加したIDをGuildFestReportListのテーブルの０番目に追加する
    List<int> reportList;
    var reportJsonList = tempListMap.first['reportDataList'];
    if( reportJsonList == null ){
      reportList = [];
    } else {
      reportList = jsonDecode( reportJsonList ).cast<int>();
    }
    reportList.insert( 0, id );
    rowGFReportList = {
      'id' : 1,  // idは必ず1でデータも1つのみでOK
      'reportDataList' : jsonEncode( reportList ),  //List<int>はjsonEncodeしてString形式で保存しておくこと
    };
    dh.update( dh.guildFestReportList, rowGFReportList );
    //##########SQLiteの操作関連ここまで################

    // Controllerの内容を消去する
    eCtrl.clear();
    // SetStateを行うことによってWidgetの内容を更新
    setState(() {});
  }

  void _duplicateReportDataItem( List<ReportData> rdl, int index ) async{

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
      'sumPoint' : 0,
      'sumRemainingPoint' : 0,
      'sumConsumedTicket' : 0,
      'sumRemainingTicket' : 0,
      'sumIncompleteTicket' : 0,
      'necessaryPoint' : '0.0', //double型はSQLite対応してないのでStringとして持つ
      'necessaryPointBP' : '0.0', //double型はSQLite対応してないのでStringとして持つ
      //'playerDataList' : null, //これは↓でupdateするので不要
    };
    final reportId = await dh.insert( dh.reportData, rowReportData );
    //追加したIDをGuildFestReportListのテーブルの０番目に追加する
    List<int> reportList;
    List<Map<String, dynamic>> tempListMap = await dh.queryAllRows( dh.guildFestReportList );
    var reportJsonList = tempListMap.first['reportDataList'];
    if( reportJsonList == null ){
      reportList = [];
    } else {
      reportList = jsonDecode( reportJsonList ).cast<int>();
    }
    reportList.insert( 0, reportId );
    Map<String, dynamic> rowGFReportList = {
      'id' : 1,  // idは必ず1でデータも1つのみでOK
      'reportDataList' : jsonEncode( reportList ),  //List<int>jsonEncodeしてString形式で保存しておくこと
    };
    dh.update( dh.guildFestReportList, rowGFReportList );
    //##########SQLiteの操作関連ここまで################

    //プレイヤー名をコピーする処理
    String playerName;
    List<int> playerList = [];
    if( rdl[index].playerDataList != null ){
      for( int i=0; i<rdl[index+1].playerDataList.length; i++ ){
        //プレイヤー追加の処理　プレイヤー名をコピーする
        playerName = rdl[index].playerDataList[i].playerName;
        quoteTicket = rdl[index].quoteTicket;

        //##########SQLiteの操作関連ここから################
        final PlayerData newPlayerData = PlayerData( playerName, quoteTicket );
        Map<String, dynamic> rowPlayerData = {
          'playerName' : playerName,
          'consumedTicket' : 0,
          'remainingTicket' : quoteTicket,
          'incompleteTicket' : 0,
          'getPoint' : 0,
          //'bonusQuest' : '', //bonusQuestは↓でupdateするので不要
          //'isBonusQuestComplete' : null, //初期値nullでいいので敢えて書かない
          //'questDataList' : '', //questDataLitも↓でupdateするので不要
        };
        final playerId = await dh.insert( dh.playerData, rowPlayerData );
        //追加したIDをReportDataのテーブルのplayerDataListに追加するためのList<int> = BLOB を作っておく
        playerList.add( playerId );

        List<String> bonusQuestList = [];
        String bonusQuestListJason;
        for( int i=0; i<3; i++ ){
          newPlayerData.bonusQuest.add(''); //SQL完了時に削除
          bonusQuestList.add('');
        }
        bonusQuestListJason = jsonEncode( bonusQuestList ); //List<String>はSQLite対応していないのでjson形式(String)で保存する
        rowPlayerData = {
          'id' : playerId,
          'bonusQuest' : bonusQuestListJason,
        };
        dh.update( dh.playerData, rowPlayerData );

        List<int> questList = [];
        for( int i=0; i<quoteTicket; i++ ){
          final QuestData newQuestData = QuestData();
          newPlayerData.questDataList.add( newQuestData );
          Map<String, dynamic> rowQuestData = {
            'questPoint' : 0,
            'questName' : '',
            //'isCompleted' : null, //これは初期値nullなので敢えて書かない
          };
          final questId = await dh.insert( dh.questData, rowQuestData );
          questList.add( questId );
        }
        rowPlayerData = {
          'id' : playerId,
          'questDataList' : jsonEncode( questList ),  //List<int>はjsonEncodeしてString形式で保存しておくこと
        };
        dh.update( dh.playerData, rowPlayerData );

        newReportData.playerDataList.add(newPlayerData);
      }
    }

    //追加したplayerIDのリストをReportDataのテーブルのplayerDataListに追加する
    rowReportData = {
      'id' : reportId,
      'playerDataList' : null,
    };
    dh.update( dh.reportData, rowReportData );
    //##########SQLiteの操作関連ここまで################

    setState(() {});
  }


  void _removeReportDataItem( List<ReportData> rdl, int deleteIndex ) async{
    dm.removeReportData( rdl[deleteIndex] ); //SQL完了時に削除
    //##########SQLiteの操作関連ここから################
    Map<String, dynamic> tmp;
    //削除するレポートデータのIDを取得　⇒　データ削除
    tmp = await dh.queryOnlyRows( dh.guildFestReportList, 1);
    List<int> tmpList = jsonDecode( tmp['reportDataList'] ).cast<int>();
    int deleteReportId = jsonDecode( tmp['reportDataList'] ).cast<int>()[deleteIndex];
    tmpList.remove( deleteReportId );
    List<int> updateGuildFestReportIdList = tmpList;
    Map<String, dynamic> rowGFReportList = {
      'id' : 1,  // idは必ず1でデータも1つのみでOK
      'reportDataList' : jsonEncode( updateGuildFestReportIdList ),
    };

    //削除するレポートに紐づいているプレイヤーIDリストを取得　⇒　データ削除
    tmp = await dh.queryOnlyRows( dh.reportData, deleteReportId);
    if( tmp['playerDataList'] != null ){
      List<int> deletePlayerIdList = jsonDecode( tmp['playerDataList'] ).cast<int>();

      //プレイヤーIDリストに紐づいているクエストIDリストを取得　⇒　データ削除
      List<int> deleteQuestIdList = [];
      for( int i=0; i<deletePlayerIdList.length; i++ ){
        tmp = await dh.queryOnlyRows( dh.questData, deletePlayerIdList[i] );
        if( tmp['questDataList'] != null ){
          for( int j=0; j<jsonDecode( tmp['questDataList'] ).cast<int>().length; j++ ){
            deleteQuestIdList.add( jsonDecode( tmp['questDataList'] ).cast<int>()[j] );
            await dh.delete( dh.questData, jsonDecode( tmp['questDataList'] ).cast<int>()[j] );
          }
        }
      }
      for( int i=0; i<deletePlayerIdList.length; i++ ){
        await dh.delete( dh.playerData, deletePlayerIdList[i] );
      }
    }

    await dh.update( dh.guildFestReportList, rowGFReportList ); //レポートリストの更新
    await dh.delete( dh.reportData, deleteReportId ); //レポートデータの削除

    //##########SQLiteの操作関連ここまで################
    setDeleteIndex(0);
    setState(() {});
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
        title: FutureBuilder<int>(
          future: _getLanguage(),
          builder: (context, snapshot) {
            return Text(
              !snapshot.hasData ? '' : def.Word().title[ snapshot.data ],
            );
          }
        ),
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
                          Row(
                            children: [
                              FlatButton(
                                onPressed: ()async{
                                  //print( await dh.queryOnlyRows( dh.guildFestReportList, 1) );
                                  //print( await dh.queryAllRows(dh.reportData) );
                                  print( await dh.queryAllRows(dh.playerData) );
                                  print( await dh.queryAllRows(dh.questData) );
                                },
                                child: Text('check'),
                              ),
                              FlatButton(
                                  onPressed: ()async{
                                    dh.deleteAll(dh.guildFestReportList);
                                    dh.deleteAll(dh.reportData);
                                    dh.deleteAll(dh.playerData);
                                    dh.deleteAll(dh.questData);
                                  },
                                  child: Text('delete'),
                              ),
                            ],
                          ),
                          ////////////////////////////////////////////////////////

                          Container(
                            padding: EdgeInsets.only( left: 8 ),
                            child: FutureBuilder<int>(
                              future: _getLanguage(),
                              builder: (context, snapshot) {
                                return Row(
                                  children: [
                                    !snapshot.hasData ? Container() : Container(
                                      child: FlatButton.icon(
                                        icon: Icon(
                                          snapshot.data == def.Language().jp
                                              ? Icons.check_box_outlined
                                              : Icons.check_box_outline_blank,
                                          color: Colors.black,
                                        ),
                                        label: Text('日本語'),
                                        textColor: Colors.black,
                                        onPressed: () {
                                          Map<String, dynamic> rowGFReportList = {
                                            'id' : 1,  // idは必ず1でデータも1つのみでOK
                                            'language' : def.Language().jp,
                                          };
                                          setState(() {
                                            dh.update( dh.guildFestReportList, rowGFReportList);
                                            dm.setLanguage( def.Language().jp ); //SQQL完了時に削除
                                          });
                                        },
                                      ),
                                    ),
                                    !snapshot.hasData ? Container() : Container(
                                      child: FlatButton.icon(
                                        icon: Icon(
                                          snapshot.data == def.Language().eng
                                              ? Icons.check_box_outlined
                                              : Icons.check_box_outline_blank,
                                          color: Colors.black,
                                        ),
                                        label: Text('English'),
                                        textColor: Colors.black,
                                        onPressed: () {
                                          Map<String, dynamic> rowGFReportList = {
                                            'id' : 1,  // idは必ず1でデータも1つのみでOK
                                            'language' : def.Language().eng,
                                          };
                                          setState(() {
                                            dh.update( dh.guildFestReportList, rowGFReportList);
                                            dm.setLanguage( def.Language().jp ); //SQQL完了時に削除
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }
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
                                            FutureBuilder<int>(
                                              future: _getLanguage(),
                                              builder: (context, snapshot) {
                                                return Text(
                                                  !snapshot.hasData ? '' :def.Word().point1[snapshot.data],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: MediaQuery.of(context).size.height * 0.025,
                                                    fontWeight: FontWeight.normal,
                                                  ),
                                                );
                                              }
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
                                            FutureBuilder<int>(
                                              future: _getLanguage(),
                                              builder: (context, snapshot) {
                                                return Text(
                                                  !snapshot.hasData ? '' : def.Word().ticket1[snapshot.data],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: MediaQuery.of(context).size.height * 0.025,
                                                    fontWeight: FontWeight.normal,
                                                  ),
                                                );
                                              }
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
                                    child: FutureBuilder<int>(
                                      future: _getLanguage(),
                                      builder: (context, snapshot) {
                                        return TextField(
                                          //事前に宣言していたTextEditingController(eCtrl）をcontrollerに代入します。
                                          controller: eCtrl,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: !snapshot.hasData ? '' : def.Word().hintText[snapshot.data],
                                            errorText: snapshot.hasData && _validate ? def.Word().errorText[snapshot.data] : null,
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
                                        );
                                      }
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
                child: FutureBuilder<List<ReportData>>(
                  future: _getReportDataItem(),
                  builder: (context, snapshot) {
                    return Container(
                      height: double.infinity,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          !snapshot.hasData ? Container() : Container(
                            margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: ListView.builder(
                                itemCount: snapshot.data.length,
                                itemBuilder: (BuildContext context, int fightDataIndex){
                                  return _buildListItem( snapshot.data, fightDataIndex );
                                }
                            ),
                          ),
                          _editReportName( snapshot.data, _editReportNameIndex ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
          FutureBuilder<List<ReportData>>(
            future: _getReportDataItem(),
            builder: (context, snapshot){
              if( snapshot.hasData ){
                return snapshot.data.length == 0
                    ? Container()
                    : _caution( snapshot.data, _deleteReportIndex );
              } else {
                return Container();
              }
            },
          )

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
                          onTap: () async{
                            //選択したReportDataのplayerDataListがIDリストの状態なので、
                            //ページ遷移するタイミングでIDリストからオブジェクトリストに置きなおす。
                            List<PlayerData> playerDataList = [];
                            List<ReportData> tmp = await _getReportDataItem();
                            List<int> playerDataIdList = tmp[index].tempList;
                            if( playerDataIdList != null ){
                              for( int i=0; i<playerDataIdList.length; i++ ){
                                Map<String, dynamic> pdlMap = await dh.queryOnlyRows( dh.playerData, playerDataIdList[i] );
                                PlayerData pd = PlayerData(
                                  pdlMap['playerName'],
                                  pdlMap['remainingTicket'],
                                  pdlMap['consumedTicket'],
                                  pdlMap['incompleteTicket'],
                                  pdlMap['getPoint'],
                                  jsonDecode( pdlMap['bonusQuest'] ).cast<String>(),
                                      (){
                                    //SQLはbool型を扱えないので、int型として保存してある
                                    // 0: true, 1: false
                                    switch( pdlMap['isBonusQuestComplete'] ){
                                      case 0:
                                        return true;
                                        break;
                                      case 1:
                                        return false;
                                        break;
                                      default :
                                        return null;
                                    }
                                  }(),
                                  null, //playerDataは、この時点ではオブジェクト化せず、tempListにIDリストの形で置いておく
                                  pdlMap['tempList']==null ? null : jsonDecode( pdlMap['tempList'] ).cast<int>(),
                                );
                                playerDataList.add( pd );
                              }
                            }
                            reportDataList[index].updateReportData('playerDataList', playerDataList);
                            Map<String, dynamic> tmpMap = await dh.queryOnlyRows( dh.guildFestReportList, 1);
                            int rdId = jsonDecode( tmpMap['reportDataList'] ).cast<int>()[index];
                            Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => FightDetail( reportDataList[index], rdId ) )
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
              : FutureBuilder<int>(
                future: _getLanguage(),
                builder: (context, snapshot) {
                  return Text(
                    !snapshot.hasData
                        ? ''
                        : '<-----${def.Word().slideGuide1[snapshot.data]}----->',
            style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
            ),
          );
                }
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
                child: FutureBuilder<int>(
                  future: _getLanguage(),
                  builder: (context, snapshot) {
                    return Text(
                      !snapshot.hasData
                          ? ''
                          : def.Word().editReportName[snapshot.data],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    );
                  }
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
                      child: FutureBuilder<int>(
                        future: _getLanguage(),
                        builder: (context, snapshot) {
                          return TextField(
                            //事前に宣言していたTextEditingController(nameCtrl）をcontrollerに代入します。
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: null,
                              errorText: snapshot.hasData && _validateEditName ? def.Word().reportNameIsEmpty[snapshot.data] : null,
                              contentPadding: EdgeInsets.all(8),
                            ),
                            onTap: () => setState(() => _validateEditName = false),
                            //Keyboardの官僚が押された際にアイテムを追加します。
                            // 必要なければ省略しても構いません。
                            onSubmitted: (reportName) async{
                              //controllerが空のときに、addListItemの処理を行わないように分岐を書きます
                              if (reportName.isEmpty) {
                                setState(() {
                                  _validateEditName = true;
                                });
                              } else {
                                //入力完了時の処理
                                reportDataList[editReportNameIndex].updateReportData('reportTitle', reportName); //SQL完了時に削除
                                //##########SQLiteの操作関連ここから################
                                Map<String, dynamic> tmp = await dh.queryOnlyRows( dh.guildFestReportList, 1);
                                int editReportId = jsonDecode( tmp['reportDataList'] ).cast<int>()[editReportNameIndex];
                                Map<String, dynamic> rowReportData = {
                                  'id' : editReportId,
                                  'reportTitle' : reportName,
                                };
                                await dh.update( dh.reportData, rowReportData );
                                //##########SQLiteの操作関連ここまで################
                                _offstageEditReportName = true;
                                setState(() {});
                              }
                            },
                          );
                        }
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
                      onPressed: () async{
                        //controllerが空のときに、addListItemの処理を行わないように分岐を書きます
                        if (nameCtrl.text.isEmpty) {
                          setState(() => _validateEditName = true);
                        } else {
                          //入力完了時の処理
                          reportDataList[editReportNameIndex].updateReportData('reportTitle', nameCtrl.text); //SQL完了時に削除
                          //##########SQLiteの操作関連ここから################
                          Map<String, dynamic> tmp = await dh.queryOnlyRows( dh.guildFestReportList, 1);
                          int editReportId = jsonDecode( tmp['reportDataList'] ).cast<int>()[editReportNameIndex];
                          Map<String, dynamic> rowReportData = {
                            'id' : editReportId,
                            'reportTitle' : nameCtrl.text,
                          };
                          await dh.update( dh.reportData, rowReportData );
                          //##########SQLiteの操作関連ここまで################
                          _offstageEditReportName = true;
                          setState(() {});
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

  Offstage _caution( List<ReportData> rdl, int deleteIndex ){
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
              FutureBuilder<int>(
                future: _getLanguage(),
                builder: (context, snapshot) {
                  return Column(
                    children: [
                      Text(
                        !snapshot.hasData
                            ? ''
                            : '${def.Word().caution1[snapshot.data]}${rdl[deleteIndex].reportTitle}${def.Word().caution2[snapshot.data]}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        !snapshot.hasData ? '' : def.Word().caution3[dm.language],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  );
                }
              ),
              Container(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RaisedButton(
                    elevation: 16,
                    child: FutureBuilder<int>(
                      future: _getLanguage(),
                      builder: (context, snapshot) {
                        return Text(
                          !snapshot.hasData ? '' : def.Word().caution4[dm.language] ,
                        );
                      }
                    ),
                    color: Colors.grey[300],
                    onPressed: () {
                      setState(() {
                        _removeReportDataItem( rdl, deleteIndex );
                        _offstageDeleteCaution = true;
                      });
                    },
                  ),
                  Container(
                    width: 20,
                  ),
                  RaisedButton(
                    elevation: 16,
                    child: FutureBuilder<int>(
                      future: _getLanguage(),
                      builder: (context, snapshot) {
                        return Text(
                          !snapshot.hasData ? '' : def.Word().caution5[snapshot.data] ,
                        );
                      }
                    ),
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
