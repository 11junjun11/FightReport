import 'dart:convert';
import 'dart:typed_data';

import 'package:fight_report/Common/AppBackgroundPage.dart';
import 'package:fight_report/Common/DataManager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:fight_report/Common/Defines.dart' as def;

class FightDetail extends StatefulWidget {
  FightDetail( this.rd, this.rdId );
  final ReportData rd;
  int rdId;
  @override
  _FightDetailState createState() => _FightDetailState();
}

class _FightDetailState extends State<FightDetail> {

  // DataBaseHelperをインスタンス化
  final dh = DatabaseHelper.instance;


  DataManager dm = new DataManager();

  List<String> _bonusQuestItems = [];
  List<String> _questPointItems = [];
  List<String> _questItems = [];
  List<String> _questItemsBackUp = [];

  //クリアしたボーナスクエスト記憶用
  int completeBonusQuestNumber;

  //プレイヤー名編集用画面のオフステージ
  bool _offstageEditPlayerName = true;

  //テキストフィールド入力チェック用
  bool _validateEditPlayerName = false;

  //プレイヤー名編集用のインデックス
  int _editPlayerNameIndex = 0;

  //Input fieldで使用するControllerの定義
  TextEditingController playerNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    //ボーナスクエストのドラムロール用のリストを作成
    for( int i=0; i<BonusQuestDatabase().bonusQuestDatabase.length; i++ ){
      _bonusQuestItems.add(BonusQuestDatabase().bonusQuestDatabase[i][dm.language]); //[0]は日本語、[1]は英語
    }
    _bonusQuestItems.insert(0, '');

    //クエストのドラムロール用のリストを作成。ポイントとクエスト名
    List<int> tmp = [];
    for( int i=0; i<QuestDatabase().questDatabase.length; i++ ){
      //ポイントは昇順に並び替えて重複していたら削除する処理
      //int型の一時的なリストを作る。ただし重複は削除
      if( tmp.indexOf(QuestDatabase().questDatabase[i][0]) == -1 ){
        tmp.add(QuestDatabase().questDatabase[i][0]);
      }
      //昇順にソートする
      tmp.sort((a, b) => b.compareTo(a));

      _questItems.add(QuestDatabase().questDatabase[i][1+dm.language]);  //[1]は日本語のクエスト名、[2]は英語のクエスト名
    }
    _questItems.insert(0, '');
    _questItemsBackUp = _questItems;

    //ポイント一覧を作る。　int ⇒ String
    for( int i=0; i<tmp.length; i++ ){
      _questPointItems.add(tmp[i].toString());
    }
    _questPointItems.insert(0, '0');

  }

  PlayerData viewPlayerData;

  void _addPlayerDataItem( String playerName ) async{
    int remainingTicket;

    //画面左側のデータを作る（PlayerData）
    remainingTicket = widget.rd.quoteTicket;

    //##########SQLiteの操作関連ここから################
    final PlayerData newPlayerData = PlayerData( playerName, remainingTicket );
    Map<String, dynamic> rowPlayerData = {
      'playerName' : playerName,
      'consumedTicket' : 0,
      'remainingTicket' : remainingTicket,
      'incompleteTicket' : 0,
      'getPoint' : 0,
      'bonusQuest' : jsonEncode( ['', '', ''] ),
      'isBonusQuestComplete' : null,
      //'questDataList' : null, //これは画面右側でupdateするので不要
    };
    final playerId = await dh.insert( dh.playerData, rowPlayerData );

    Map<String, dynamic> tmp = await dh.queryOnlyRows( dh.reportData, widget.rdId );
    Map<String, dynamic> rowReportData;
    List<int> playerIdList;
    if( tmp['playerDataList'] != null ){
      playerIdList = List.from( tmp['playerDataList'] );
      playerIdList.add( playerId );
      rowReportData = {
        'id' : widget.rdId,
        'playerDataList' : Uint8List.fromList( playerIdList ),
      };
    } else {
      playerIdList = [playerId];
      rowReportData = {
        'id' : widget.rdId,
        'playerDataList' : Uint8List.fromList( playerIdList ),
      };
    }
    await dh.update( dh.reportData, rowReportData );


    //画面右側のデータを作る（questData）
    for( int i=0; i<3; i++ ){
      newPlayerData.bonusQuest.add('');
    }
    for( int i=0; i<remainingTicket; i++ ){
      final QuestData newQuestData = QuestData();
      newPlayerData.questDataList.add( newQuestData );
    }

    widget.rd.playerDataList.add(newPlayerData);
    _calcAll( newPlayerData );
    setState(() {});
  }

  Future<List<PlayerData>> _getPlayerDataItem() async{
    //まずはプレイヤーIDのリストを取得する
    List<PlayerData> playerDataList = [];
    Map<String, dynamic> tmpMap = await dh.queryOnlyRows( dh.reportData, widget.rdId );
    var playerDataIdUint8List = tmpMap['playerDataList'];
    List<int> playerDataIdList = List.from( playerDataIdUint8List );

    //レポートIDに紐づけられたレポートデータを取得する
    for( int i=0; i<playerDataIdList.length; i++ ){
      Map<String, dynamic> tmp = await dh.queryOnlyRows( dh.reportData, playerDataIdList[i] );
      PlayerData pd = PlayerData(
        tmp['playerName'],
        tmp['remainingTicket'],
        tmp['consumedTicket'],
        tmp['incompleteTicket'],
        tmp['getPoint'],
        jsonDecode( tmp['bonusQuest'] ),
        (){
          switch( tmp['isBonusQuestComplete'] ){
            case 0 :
              return true;
              break;
            case 1:
              return false;
              break;
            default :
              return null;
          }
        }(),
        //tmp['questDataList'], //クエストデータは初期値[]なので敢えて書かない
        //tmp['tempList'], //これいらんかも
      );
      playerDataList.add( pd );
    }

    return playerDataList;
  }

  void _removePlayerDataItem( PlayerData pd ){
    setState(() {
      widget.rd.playerDataList.remove( pd );
      if( pd == viewPlayerData ){
        viewPlayerData = null;
      }
      _calcAll( pd );
    });
  }

  void _viewPlayerData( PlayerData pd ){
    setState(() {
      viewPlayerData = pd;
    });
  }

  //ドラムロール表示用メソッド
  void _showModalPicker(BuildContext context, PlayerData pd, List<String> items, int questIndex) {
    String initialItem;
    if( items == _bonusQuestItems ){
      initialItem = pd.bonusQuest[questIndex];
    }
    if( items == _questPointItems ){
      initialItem = pd.questDataList[questIndex].questPoint.toString();
    }
    if( items == _questItems ){
      initialItem = pd.questDataList[questIndex].questName;
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
              onSelectedItemChanged: (index) => _onSelectedItemChanged(items, pd, questIndex, index),
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

  //ドラムロールで選択したものに更新するメソッド
  void _onSelectedItemChanged(List<String> items, PlayerData pd, int questIndex, int itemIndex) {
    setState(() {
      if( items == _bonusQuestItems ){
        pd.bonusQuest[questIndex] = items[itemIndex];
      }
      if( items == _questPointItems ){
        pd.questDataList[questIndex].questPoint = int.parse(items[itemIndex]);
        _narrowDownQuestItems( pd, questIndex, pd.questDataList[questIndex].questPoint );
      }
      if( items == _questItems ){
        pd.questDataList[questIndex].questName = items[itemIndex];
      }
    });
  }

  //クエストポイントを選んだらそのポイントに該当するクエストだけに絞り込むメソッド
  void _narrowDownQuestItems( PlayerData pd, int questIndex, int questPoint ){
    var _list = QuestDatabase().questDatabase;
    _questItems = [];
    for( int i=0; i<_list.length; i++ ){
      if( _list[i][0] == questPoint ){
        _questItems.add(_list[i][1+dm.language]);
      }
    }
    if( _questItems.length == 1 ){
      pd.questDataList[questIndex].questName = _questItems.first;
    }
    if( _questItems.length > 1 ){
      pd.questDataList[questIndex].questName = '';
    }
    if( _questItems.length == 0 ){
      pd.questDataList[questIndex].questName = '';
    }
    setState(() {});
  }

  int _countConsumedTicket( PlayerData pd ){
    int _num = 0;
    for( int i=0; i<pd.questDataList.length; i++ ){
      if( pd.questDataList[i].isCompleted != null ){
        _num++;
      }
    }
    pd.updatePlayerData('consumedTicket', _num);
    return _num;
  }

  int _countRemainingTicket( PlayerData pd ){
    int _num = pd.remainingTicket;
    _num = widget.rd.quoteTicket - pd.consumedTicket;
    pd.updatePlayerData('remainingTicket', _num);
    return _num;
  }

  int _countIncompleteTicket( PlayerData pd ){
    int _num = 0;
    for( int i=0; i<pd.questDataList.length; i++ ){
      if( pd.questDataList[i].isCompleted == false ){
        _num++;
      }
    }
    pd.updatePlayerData('incompleteTicket', _num);
    return _num;
  }

  int _countGetPoint( PlayerData pd ){
    int _point = 0;
    //ボーナスポイント加算
    if( pd.isBonusQuestComplete == true ){
      _point += 175;
    }
    //クエストポイント加算
    for( int i=0; i<pd.questDataList.length; i++ ){
      if( pd.questDataList[i].isCompleted == true ){
        _point += pd.questDataList[i].questPoint;
      }
    }
    pd.updatePlayerData('getPoint', _point);
    return _point;
  }

  String _formatNum( dynamic num ){
    String _result;
    final formatterInt = NumberFormat("#,###");
    final formatterDouble = NumberFormat("#,###.0");
    if( num.runtimeType == int ){
      _result = formatterInt.format(num);
    }
    if( num.runtimeType == double ){
      _result = formatterDouble.format(num);
    }
    return _result;
  }



  int _countSumPoint(){
    int _point = 0;
    for( int i=0; i<widget.rd.playerDataList.length; i++ ){
      _point += widget.rd.playerDataList[i].getPoint;
    }
    widget.rd.updateReportData('sumPoint', _point);
    return _point;
  }

  int _countSumRemainingPoint(){
    int _num = 0;
    _num = widget.rd.quotePoint * widget.rd.playerDataList.length - widget.rd.sumPoint;
    if( _num < 0 ){
      _num = 0;
    }
    widget.rd.updateReportData('sumRemainingPoint', _num);
    return _num;
  }

  int _countSumConsumedTicket(){
    int _num = 0;
    for( int i=0; i<widget.rd.playerDataList.length; i++ ){
      _num += widget.rd.playerDataList[i].consumedTicket;
    }
    widget.rd.updateReportData('sumConsumedTicket', _num);
    return _num;
  }

  int _countSumRemainingTicket(){
    int _num = 0;
    for( int i=0; i<widget.rd.playerDataList.length; i++ ){
      _num += widget.rd.playerDataList[i].remainingTicket;
    }
    widget.rd.updateReportData('sumRemainingTicket', _num);
    return _num;
  }

  int _countSumIncompleteTicket(){
    int _num = 0;
    for( int i=0; i<widget.rd.playerDataList.length; i++ ){
      _num += widget.rd.playerDataList[i].incompleteTicket;
    }
    widget.rd.updateReportData('sumIncompleteTicket', _num);
    return _num;
  }

  double _countNecessaryPoint(){
    double _ave = 0.0;
    _ave = widget.rd.sumRemainingPoint.toDouble() / widget.rd.sumRemainingTicket;
    widget.rd.updateReportData('necessaryPoint', _ave);
    return _ave;
  }

  double _countNecessaryPointBP(){
    double _ave = 0.0;
    int _getBonusPointIfAllBonusQuestCompleted = 0;
    for( int i=0; i<widget.rd.playerDataList.length; i++ ){
      if( widget.rd.playerDataList[i].isBonusQuestComplete == null ){
        _getBonusPointIfAllBonusQuestCompleted += 175;
      }
    }
    _ave = ( widget.rd.sumRemainingPoint -_getBonusPointIfAllBonusQuestCompleted ) / widget.rd.sumRemainingTicket;
    if( _ave < 0.0 ){
      _ave = 0.0;
    }
    widget.rd.updateReportData('necessaryPointBP', _ave);
    return _ave;
  }

  void _calcAll( [PlayerData pd] ){
    _countConsumedTicket( pd );
    _countRemainingTicket( pd );
    _countIncompleteTicket( pd );
    _countGetPoint( pd );
    _countSumPoint();
    _countSumRemainingPoint();
    _countSumConsumedTicket();
    _countSumRemainingTicket();
    _countSumIncompleteTicket();
    _countNecessaryPoint();
    _countNecessaryPointBP();
  }

  void setIndex( int index ){
    _editPlayerNameIndex = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text( widget.rd.reportTitle ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          AppBackgroundPage(),
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            child: Row(
                              children: [
                                Column(
                                  children: [
                                    _buildChartView(
                                      '${def.Word().targetPoint[dm.language]}: ', widget.rd.quotePoint*widget.rd.playerDataList.length,
                                      '${def.Word().sum[dm.language]}: ', widget.rd.sumPoint,
                                      '${def.Word().remPoint[dm.language]}: ', widget.rd.sumRemainingPoint,
                                    ),
                                    _buildChartView(
                                      '${def.Word().allTickets[dm.language]}: ', widget.rd.quoteTicket * widget.rd.playerDataList.length,
                                      '${def.Word().fin1[dm.language]}: ', widget.rd.sumConsumedTicket,
                                      '${def.Word().remTicket[dm.language]}: ', widget.rd.sumRemainingTicket,
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.only(
                                    left: MediaQuery.of(context).size.width * 0.5 * 0.4 * 0.1,
                                    right: MediaQuery.of(context).size.width * 0.5 * 0.4 * 0.05,
                                  ),
                                  width: MediaQuery.of(context).size.width * 0.5 * 0.4,
                                  child: Column(
                                    children: [
                                      _buildOtherInfoView( 'trgt pt/plyr', '${def.Word().trgtPointPlayer[dm.language]}:', widget.rd.quotePoint ),
                                      _buildOtherInfoView(  'Ave. w/o BP', '${def.Word().ave1[dm.language]} :', widget.rd.necessaryPoint ),
                                      _buildOtherInfoView( 'Ave. with BP', '${def.Word().ave2[dm.language]}:', widget.rd.necessaryPointBP ),
                                      _buildOtherInfoView( 'tickets/plyr', '${def.Word().ticketsPlayer[dm.language]}:', widget.rd.quoteTicket ),
                                      _buildOtherInfoView( 'mistaken tickets','${def.Word().mistakenTickets[dm.language]}:', widget.rd.sumIncompleteTicket ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: MediaQuery.of(context).size.height * 0.06,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(8.0),
                              ),

                            ),
                            child: Row(
                              children: [
                                _buildTitle( def.Word().no[dm.language] , 1.0 ),
                                _buildTitle( def.Word().playerName[dm.language] , 4.0 ),
                                Row(
                                  children: [
                                    _buildTitle( def.Word().fin2[dm.language] , 1.0 ),
                                    _buildTitle( def.Word().rem[dm.language] , 1.0 ),
                                    _buildTitle( def.Word().miss[dm.language] , 1.0 ),
                                    _buildTitle( def.Word().pt[dm.language] , 2.0 ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              //margin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                              height: double.infinity,
                              width: double.infinity,
                              child: widget.rd.playerDataList.length == 0
                                  ? Container(
                                alignment: Alignment.topCenter,
                                child: IconButton(
                                  icon: Icon(Icons.add_circle_outline),
                                  onPressed: (){
                                    _addPlayerDataItem('${def.Word().player[dm.language]}1');
                                  },
                                ),
                              )
                                  : ListView.builder(
                                      itemCount: widget.rd.playerDataList.length,
                                      itemBuilder: (BuildContext context, int index){
                                        return _buildListItem(widget.rd.playerDataList, index);
                                      }
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Offstage(
                      offstage: _offstageEditPlayerName,
                      child: GestureDetector(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey.withOpacity(0.8),
                          //プレイヤー名を編集する時のテキストフィールド
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.only( left: 8, bottom: 4 ),
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  def.Word().editPlayerName[dm.language],
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
                                        controller: playerNameCtrl,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: null,
                                          errorText: _validateEditPlayerName ? def.Word().playerNameIsEmpty[dm.language] : null,
                                          contentPadding: EdgeInsets.all(8),
                                        ),
                                        onTap: () => setState(() => _validateEditPlayerName = false),
                                        //Keyboardの官僚が押された際にアイテムを追加します。
                                        // 必要なければ省略しても構いません。
                                        onSubmitted: (playerName) {
                                          //controllerが空のときに、addListItemの処理を行わないように分岐を書きます
                                          if (playerName.isEmpty) {
                                            setState(() {
                                              _validateEditPlayerName = true;
                                            });
                                          } else {
                                            //入力完了時の処理
                                            setState(() {
                                              widget.rd.playerDataList[_editPlayerNameIndex].updatePlayerData('playerName', playerName);
                                              _offstageEditPlayerName = true;
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
                                        if (playerNameCtrl.text.isEmpty) {
                                          setState(() => _validateEditPlayerName = true);
                                        } else {
                                          //入力完了時の処理
                                          setState(() {
                                            widget.rd.playerDataList[_editPlayerNameIndex].updatePlayerData('playerName', playerNameCtrl.text);
                                            _offstageEditPlayerName = true;
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
                            _offstageEditPlayerName = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    viewPlayerData == null
                        ? Container()
                        : _playerDataDetail( viewPlayerData ),
                    Offstage(
                      offstage: _offstageEditPlayerName,
                      child: GestureDetector(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey.withOpacity(0.8),
                        ),
                        onTap: (){
                          setState(() {
                            _offstageEditPlayerName = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Container _buildChartView(
      String text1, int value1,
      String text2, int value2,
      String text3, int value3,
      ){

    double _barRateBlue = 0.0;
    double _barRateGrey = 0.0;
    if( value2.toDouble() != 0.0 && value3.toDouble() != 0.0 ){
      _barRateBlue = value2.toDouble() / (value2.toDouble() + value3.toDouble());
      if( _barRateBlue > 1.0 ){ _barRateBlue = 1.0; }
      _barRateGrey = value3.toDouble() / (value2.toDouble() + value3.toDouble());
      if( _barRateGrey < 0.0 ){ _barRateGrey = 0.0; }
    } else {
      _barRateBlue = 0.0;
      _barRateGrey = 1.0;
    }

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 1,
      ),
      width: MediaQuery.of(context).size.width * 0.5 * 0.6,
      //height: MediaQuery.of(context).size.height * 0.12,
      child: Column(
        children: [
          Container(
            //目標表示部分
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text1,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.03,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
                Text(
                  _formatNum( value1 ),
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.04,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            //バー表示用
            height: 5,
            child: Row(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.5 * 0.6 * _barRateBlue,
                  height: 5,
                  color: Colors.blueAccent,
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.5 * 0.6 * _barRateGrey,
                  height: 5,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
          Container(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    //現在値の表示部分
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.6 * 0.01,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          text2,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.03,
                            fontWeight: FontWeight.normal,
                            color: Colors.blue,
                          ),
                        ),
                        Container(
                          child: Text(
                            _formatNum( value2 ),
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.height * 0.04,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    //残り表示部分
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.6 * 0.01,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          text3,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.03,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          _formatNum( value3 ),
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Container _buildOtherInfoView ( String key, String text, dynamic value ){
    return Container(
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.height * 0.03,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                _formatNum( value ),
                style: TextStyle(
                  color: (){
                    switch(key){
                      case 'mistaken tickets':
                        if( value > 0 ){
                          return Colors.redAccent;
                        } else {
                          return Colors.black;
                        }
                        break;
                      default :
                        return Colors.black;
                    }
                  }(),
                  fontWeight: (){
                    switch(key){
                      case 'mistaken tickets':
                        if( value > 0 ){
                          return FontWeight.bold;
                        } else {
                          return FontWeight.normal;
                        }
                        break;
                      default :
                        return FontWeight.normal;
                    }
                  }(),
                  fontSize: (){
                    switch(key){
                      case 'mistaken tickets':
                        if( value > 0 ){
                          return MediaQuery.of(context).size.height * 0.05;
                        } else {
                          return MediaQuery.of(context).size.height * 0.03;
                        }
                        break;
                      default :
                        return MediaQuery.of(context).size.height * 0.03;
                    }
                  }(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Container _buildTitle( String text, double widthRate ){
    return Container(
      alignment: Alignment.center,
      width: MediaQuery.of(context).size.width * 0.05 * widthRate,
      decoration: text == 'pt' ? null : BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.grey,
            width: 1,
          ),
        ),
      ),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: MediaQuery.of(context).size.height * 0.03,
          ),
        ),
      ),
    );
  }

  Container _buildListItem(List<PlayerData> playerDataList, int index) {
    return Container(
      child: Column(
        children: [
          Dismissible(
              key: ObjectKey(playerDataList[index]),
              child: Column(
                children: [
                  Slidable(
                    actionExtentRatio: 0.18,
                    actionPane: SlidableDrawerActionPane(),
                    child: Container(
                      //margin: EdgeInsets.symmetric(vertical: 2),
                      //padding: EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: viewPlayerData != playerDataList[index]
                            ? null
                            : Colors.blue[200],
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                      ),
                      height: MediaQuery.of(context).size.height * 0.1,
                      child: GestureDetector(
                        child: Row(
                          children: [
                            _buildPlayerDataView(
                              def.Word().no[dm.language],
                              index+1,
                              1.0 ,
                            ),
                            _buildPlayerDataView(
                              def.Word().playerName[dm.language],
                              playerDataList[index].playerName,
                              4.0,
                            ),
                            Row(
                              children: [
                                _buildPlayerDataView(
                                  def.Word().fin2[dm.language],
                                  _countConsumedTicket( playerDataList[index] ),
                                  1.0,
                                ),
                                _buildPlayerDataView(
                                  def.Word().rem[dm.language],
                                  _countRemainingTicket( playerDataList[index] ),
                                  1.0,
                                ),
                                _buildPlayerDataView(
                                  def.Word().miss[dm.language],
                                  _countIncompleteTicket( playerDataList[index] ),
                                  1.0,
                                ),
                                _buildPlayerDataView(
                                  def.Word().pt[dm.language],
                                  _countGetPoint( playerDataList[index] ),
                                  2.0,
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: (){
                          _viewPlayerData( playerDataList[index] );
                        },
                      ),
                    ),

                    //右にスライドした時
                    actions: [
                      IconSlideAction(
                        caption: def.Word().editPlayerName[dm.language],
                        color: Colors.grey[200].withOpacity(0.0),
                        icon: Icons.edit_outlined,
                        onTap: () {
                          //プレイヤー名編集の処理
                          setState(() {
                            setIndex(index);
                            //レポート名編集用のテキストフィールドに初期値（もともとのレポート名）を設定
                            playerNameCtrl = TextEditingController(
                              text: playerDataList[index].playerName,
                            );
                            _offstageEditPlayerName = false;
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
                          _removePlayerDataItem( playerDataList[index] );
                        },
                      ),
                    ],
                  ),
                ],
              ),
          ),
          playerDataList.length != index+1
              ? Container()
              : Column(
                children: [
                  Text(
                    '<-----${def.Word().slideGuide2[dm.language]}----->',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    child: IconButton(
                      icon: Icon(Icons.add_circle_outline),
                      onPressed: (){
                        _addPlayerDataItem('${def.Word().player[dm.language]}${playerDataList.length+1}');
                      },
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Container _buildPlayerDataView( String key, dynamic data, double widthRate ){
    return Container(
      alignment: Alignment.center,
      width: MediaQuery.of(context).size.width * 0.05 * widthRate,
      decoration: BoxDecoration(
        //color: Colors.blueAccent,
        border: Border(
          right: BorderSide(
            color: Colors.grey,
            width: 1,
          ),
          left: BorderSide(
            color: Colors.grey,
            width: key == 'No.' ? 1 : 0,
          ),
        ),
      ),
      child: RichText(
        text: TextSpan(
          text: (){
            switch(key){
              case 'player name':
                return data;
                break;
              case 'pt':
                return _formatNum( data );
                break;
              default :
                return data.toString();
            }
          }(),
          style: TextStyle(
            color: (){
              switch(key){
                case 'No.':
                  return Colors.grey;
                  break;
                case 'fin':
                  if( data == widget.rd.quoteTicket ){
                    return Colors.blue;
                  } else {
                    return Colors.black;
                  }
                  break;
                case 'rem':
                  if( data == 0 ){
                    return Colors.blue;
                  } else {
                    return Colors.black;
                  }
                  break;
                case 'miss':
                  if( data != 0 ){
                    return Colors.redAccent;
                  } else if( data == 0 ){
                    return Colors.blue;
                  } else {
                    return Colors.black;
                  }
                  break;
                case 'pt':
                  if( data >= widget.rd.quotePoint ){
                    return Colors.blue;
                  } else {
                    return Colors.black;
                  }
                  break;
                default:
                  return Colors.black;
              }
            }(),
            fontWeight: (){
              switch(key){
                case 'No.':
                  return FontWeight.normal;
                  break;
                default :
                  return FontWeight.bold;
              }
            }(),
            fontSize: (){
              switch(key){
                case 'No.':
                  return MediaQuery.of(context).size.height * 0.035;
                  break;
                default :
                  return MediaQuery.of(context).size.height * 0.045;
              }
            }(),
          ),
        ),
      ),
    );
  }

  Container _playerDataDetail( PlayerData pd ){
    return Container(
      margin: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.5 * 0.05 / 2),
      width: double.infinity,
      height: double.infinity,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              //ボーナスクエストの表示部分
              height: MediaQuery.of(context).size.height * 3/(3+11+4),
              //color: Colors.green,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey,
                          width: 1,
                        ),

                      ),
                    ),
                    alignment: Alignment.center,
                    width: MediaQuery.of(context).size.width * 0.5 * 0.1,
                    child: Text(
                      'BQ',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Container(
                    color: ((){
                      switch( pd.isBonusQuestComplete ){
                        case true:
                          return Colors.greenAccent;
                          break;
                        case false:
                          return Colors.redAccent;
                          break;
                        default:
                          return null;
                      }
                    }()),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey,
                                width: 1,
                              ),

                            ),
                          ),
                          alignment: Alignment.center,
                          width: MediaQuery.of(context).size.width * 0.5 * 0.15,
                          //color: Colors.lightBlueAccent,
                          child: Text(
                            '175',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          //ボーナスクエスト３つ分を表示するウィジェット
                          width: MediaQuery.of(context).size.width * 0.5 * 0.5,
                          //color: Colors.orange,
                          child: ListView.builder(
                            itemCount: 3,
                            itemBuilder: (BuildContext context, int questIndex){
                              return GestureDetector(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey,
                                        width: 1,
                                      ),

                                    ),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  height: MediaQuery.of(context).size.height * 1/(3+11+4),
                                  child: RichText(
                                    text: TextSpan(
                                      text: pd.bonusQuest[questIndex] == '' ? ' ▼' : pd.bonusQuest[questIndex],
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: pd.bonusQuest[questIndex] != ''
                                            ? MediaQuery.of(context).size.height * 0.04
                                            : MediaQuery.of(context).size.height * 0.02,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                onTap: (){
                                  _showModalPicker(context, pd, _bonusQuestItems, questIndex);
                                },
                              );
                            },
                          ),
                        ),
                        Container(
                            alignment: Alignment.center,
                            width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                            child: ListView.builder(
                              itemCount: 3,
                              itemBuilder: (BuildContext context, int index){
                                return Container(
                                  alignment: Alignment.center,
                                  width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  height: MediaQuery.of(context).size.height * 1/(3+11+4),
                                  child: ((){
                                    switch( pd.isBonusQuestComplete ){
                                      case true:
                                        return Container(
                                          width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                                          child: index != completeBonusQuestNumber ? Container() : IconButton(
                                            icon: Icon(Icons.check),
                                            iconSize: MediaQuery.of(context).size.height * 0.5/(3+11+4),
                                            onPressed: (){
                                              setState(() {
                                                pd.isBonusQuestComplete = false;
                                                completeBonusQuestNumber = null;
                                                _calcAll( pd );
                                              });
                                            },
                                          ),
                                        );
                                        break;
                                      case false:
                                        return Container(
                                          width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                                          child: IconButton(
                                            icon: Icon(Icons.clear),
                                            iconSize: MediaQuery.of(context).size.height * 0.5/(3+11+4),
                                            onPressed: (){
                                              setState(() {
                                                pd.updatePlayerData('isBonusQuestComplete', null);
                                                completeBonusQuestNumber = null;
                                                _calcAll( pd );
                                              });
                                            },
                                          ),
                                        );
                                        break;
                                      default:
                                        return Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: MediaQuery.of(context).size.height * 0.1/(3+11+4),
                                            horizontal: MediaQuery.of(context).size.width * 0.5 * 0.2 * 0.05,
                                          ),
                                          alignment: Alignment.center,
                                          width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                                          child: RaisedButton(
                                            child: Text(
                                              def.Word().result[dm.language],
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.normal,
                                                fontSize: MediaQuery.of(context).size.height * 0.5/(3+11+4),
                                              ),
                                            ),
                                            color: Colors.grey,
                                            shape: StadiumBorder(),
                                            onPressed: () {
                                              if( pd.bonusQuest[index] != '' ){
                                                setState(() {
                                                  pd.updatePlayerData('isBonusQuestComplete', true);
                                                  completeBonusQuestNumber = index;
                                                  _calcAll( pd );
                                                });
                                              }
                                            },
                                          ),
                                        );
                                    }
                                  }()),
                                );
                              },
                            )
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              //クエストの一覧表示部分
              height: MediaQuery.of(context).size.height * 11/(3+11+4),
              //color: Colors.lightBlueAccent,
              child: ListView.builder(
                itemCount: widget.rd.quoteTicket,
                itemBuilder: (BuildContext context, int index){
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey,
                            width: 1,
                          ),
                        ),
                      ),
                      height: MediaQuery.of(context).size.height * 1/(3+11+4),
                      child: Row(
                        children: [
                          Container(
                            alignment: Alignment.center,
                            width: MediaQuery.of(context).size.width * 0.5 * 0.1,
                            child: Text(
                              (index+1).toString(),
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.normal,
                                fontSize: MediaQuery.of(context).size.height * 0.035,
                              ),
                            ),
                          ),
                          Container(
                            color: ((){
                              switch( pd.questDataList[index].isCompleted ){
                                case true:
                                  return Colors.greenAccent;
                                  break;
                                case false:
                                  return Colors.redAccent;
                                  break;
                                default:
                                  return null;
                              }
                            }()),
                            child: Row(
                              children: [
                                GestureDetector(
                                  child: Container(
                                    alignment: Alignment.center,
                                    width: MediaQuery.of(context).size.width * 0.5 * 0.15,
                                    child: Text(
                                      pd.questDataList[index].questPoint == null
                                          ? ''
                                          : pd.questDataList[index].questPoint.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  onTap: (){
                                    _showModalPicker(context, pd, _questPointItems, index);
                                  },
                                ),
                                GestureDetector(
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    width: MediaQuery.of(context).size.width * 0.5 * 0.5,
                                    child: (){
                                      if( index == 0 && pd.questDataList[index].questPoint == 0 ){
                                        return Text(
                                          '<--${def.Word().tapGuide[dm.language]}',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      } else {
                                        return Text(
                                          pd.questDataList[index].questName == '' && pd.questDataList[index].questPoint != 0
                                              ? '　▼'
                                              : pd.questDataList[index].questName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: pd.questDataList[index].questName != ''
                                                ? MediaQuery.of(context).size.height * 0.04
                                                : MediaQuery.of(context).size.height * 0.02,
                                          ),
                                        );
                                      }
                                    }()
                                  ),
                                  onTap: (){
                                    if( pd.questDataList[index].questPoint != 0 && _questItems.length > 1){
                                      _showModalPicker(context, pd, _questItems, index);
                                    }
                                  },
                                ),
                                ((){
                                  switch( pd.questDataList[index].isCompleted ){
                                    case true:
                                      return Container(
                                        width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                                        child: IconButton(
                                          icon: Icon(Icons.check),
                                          iconSize: MediaQuery.of(context).size.height * 0.5/(3+11+4),
                                          onPressed: (){
                                            setState(() {
                                              pd.questDataList[index].isCompleted = false;
                                              _calcAll( pd );
                                            });
                                          },
                                        ),
                                      );
                                      break;
                                    case false:
                                      return Container(
                                        width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                                        child: IconButton(
                                          icon: Icon(Icons.clear),
                                          iconSize: MediaQuery.of(context).size.height * 0.5/(3+11+4),
                                          onPressed: (){
                                            setState(() {
                                              pd.questDataList[index].updateQuestData('isCompleted', null);
                                              _calcAll( pd );
                                            });
                                          },
                                        ),
                                      );
                                      break;
                                    default:
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: MediaQuery.of(context).size.height * 0.1/(3+11+4),
                                          horizontal: MediaQuery.of(context).size.width * 0.5 * 0.2 * 0.05,
                                        ),
                                        alignment: Alignment.center,
                                        width: MediaQuery.of(context).size.width * 0.5 * 0.2,
                                        child: RaisedButton(
                                          child: Text(
                                            def.Word().result[dm.language],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.normal,
                                              fontSize: MediaQuery.of(context).size.height * 0.5/(3+11+4),
                                            ),
                                          ),
                                          color: Colors.grey,
                                          shape: StadiumBorder(),
                                          onPressed: () {
                                            if( pd.questDataList[index].questName != '' ) {
                                              pd.questDataList[index].updateQuestData('isCompleted', true);
                                              _calcAll( pd );
                                              setState(() {});
                                            }
                                          },
                                        ),
                                      );
                                  }
                                }()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
              ),
            ),
          ],
        ),
      ),
    );
  }

}

