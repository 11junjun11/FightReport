import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:intl/intl.dart';


//////////////////////////////////////////////////////////////
//SQLiteデータベース用のクラス DatabaseHelper
//////////////////////////////////////////////////////////////
class DatabaseHelper {

  final _databaseName = "GuildFestReport.db"; // DB名
  final _databaseVersion = 1; // 1で固定？

  final guildFestReportList = 'GuildFestReportList'; // テーブル名：GuildFestReportList
  final reportData = 'ReportData'; // テーブル名：ReportData
  final playerData = 'PlayerData'; // テーブル名：PlayerData
  final questData = 'QuestData'; // テーブル名：QuestData



  // DatabaseHelperクラスをシングルトンにするためのコンストラクタ
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // DBにアクセスするためのメソッド
  static Database _database;
  Future<Database> get database async {
    if (_database != null) return _database;
    // 初の場合はDBを作成する
    _database = await _initDatabase();
    return _database;
  }

  // データベースを開く。データベースがない場合は作る関数
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory(); // アプリケーション専用のファイルを配置するディレクトリへのパスを返す
    String path = join(documentsDirectory.path, _databaseName); // joinはセパレーターでつなぐ関数
    // pathのDBを開く。なければonCreateの処理がよばれる。onCreateでは_onCreateメソッドを呼び出している
    return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
    );
  }

  // DBを作成するメソッド
  Future _onCreate(Database db, int version) async {
    // ダブルクォートもしくはシングルクォート3つ重ねることで改行で文字列を作成できる。$変数名は、クラス内の変数のこと（文字列の中で使える）
    await db.execute("""
            CREATE TABLE $guildFestReportList
              (
                id INTEGER,
                language INTEGER,
                reportDataList BLOB
              )
            """);
    await db.execute("""
            CREATE TABLE $reportData
              (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reportTitle TEXT,
                date TEXT,
                quotePoint INTEGER,
                quoteTicket INTEGER,
                sumPoint INTEGER,
                sumRemainingPoint INTEGER,
                sumConsumedTicket INTEGER,
                sumRemainingTicket INTEGER,
                sumIncompleteTicket INTEGER,
                necessaryPoint TEXT,
                necessaryPointBP TEXT,
                playerDataList BLOB
              )
            """);
    await db.execute("""
            CREATE TABLE $playerData
              (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                playerName TEXT,
                consumedTicket INTEGER,
                remainingTicket INTEGER,
                incompleteTicket INTEGER,
                getPoint INTEGER,
                bonusQuest TEXT,
                isBonusQuestComplete INTEGER,
                questDataList BLOB
              )
            """);
    await db.execute("""
            CREATE TABLE $questData
              (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                questPoint INTEGER,
                questName TEXT,
                isCompleted INTEGER
              )
            """);
  }

  // Helper methods

  // 挿入
  Future<int> insert( String table, Map<String, dynamic> row ) async {
    Database db = await instance.database; //DBにアクセスする
    return await db.insert(table, row); //テーブルにマップ型のものを挿入。追加時のrowIDを返り値にする
  }

  // 全件取得
  Future<List<Map<String, dynamic>>> queryAllRows( String table ) async {
    Database db = await instance.database; //DBにアクセスする
    return await db.query(table); //全件取得
  }

  // データ件数取得
  Future<int> queryRowCount( String table ) async {
    Database db = await instance.database; //DBにアクセスする
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table'));
  }

  // 更新
  Future<int> update( String table, Map<String, dynamic> row ) async {
    Database db = await instance.database; //DBにアクセスする
    int id = row['id']; //引数のマップ型のcolumnIDを取得
    print([id]);
    return await db.update(table, row, where: 'id = ?', whereArgs: [id]);
  }

  // 削除
  Future<int> delete( String table, [ int id ] ) async {
    Database db = await instance.database;
    return await db.delete( table ); //暫定でテーブルデータをすべて削除するようにしておく。
    //return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}



//////////////////////////////////////////////////////////////
//データを一元管理するクラス
//////////////////////////////////////////////////////////////
class DataManager{

  int language = 0;
  List<ReportData> guildFestReportList = [];

  static final DataManager _cache = DataManager._internal();
  DataManager._internal();

  factory DataManager() {
    return _cache;
  }

  void setLanguage( int lang ){
    language = lang;
  }

  void addReportData( ReportData newReportData ){
    guildFestReportList.insert(0, newReportData);
  }

  void removeReportData( ReportData removeReportData ) {
    guildFestReportList.remove( removeReportData );
  }

}


class ReportData {
  ReportData( this.reportTitle, this.date, this.quotePoint, this.quoteTicket );
  String reportTitle;
  final DateTime date;
  int quotePoint = 0;
  int quoteTicket = 0;
  int sumPoint = 0;
  int sumRemainingPoint = 0;
  int sumConsumedTicket = 0;
  int sumRemainingTicket = 0;
  int sumIncompleteTicket = 0;
  double necessaryPoint = 0.0;
  double necessaryPointBP = 0.0;
  List<PlayerData> playerDataList = [];


  void addPlayerData( PlayerData newPlayerData ){
    playerDataList.add(newPlayerData);
  }

  void removePlayerData( PlayerData removeAccountData ) async{
    playerDataList.remove(removeAccountData);
  }

  void updateReportData( String key, dynamic data ){
    switch(key){
      case 'reportTitle':
        reportTitle = data;
        break;
      case 'quotePoint':
        quotePoint = data;
        break;
      case 'quoteTicket':
        quoteTicket = data;
        break;
      case 'sumPoint':
        sumPoint = data;
        break;
      case 'sumRemainingPoint':
        sumRemainingPoint = data;
        break;
      case 'sumConsumedTicket':
        sumConsumedTicket = data;
        break;
      case 'sumRemainingTicket':
        sumRemainingTicket = data;
        break;
      case 'sumIncompleteTicket':
        sumIncompleteTicket = data;
        break;
      case 'necessaryPoint':
        necessaryPoint = data;
        break;
      case 'necessaryPointBP':
        necessaryPointBP = data;
        break;
      case 'playerDataList':
        playerDataList = data;
        break;
      default:
        break;
    }
  }

}

class PlayerData {
  PlayerData( this.playerName, this.remainingTicket );
  String playerName;
  int consumedTicket = 0;
  int remainingTicket = 0;
  int incompleteTicket = 0;
  int getPoint = 0;
  List<String> bonusQuest = ['', '', ''];
  bool isBonusQuestComplete;
  List<QuestData> questDataList = [];

  void updatePlayerData( String key, dynamic data ){
    switch(key){
      case 'playerName':
        playerName = data;
        break;
      case 'consumedTicket':
        consumedTicket = data;
        break;
      case 'remainingTicket':
        remainingTicket = data;
        break;
      case 'incompleteTicket':
        incompleteTicket = data;
        break;
      case 'getPoint':
        getPoint = data;
        break;
      case 'bonusQuest':
        bonusQuest = data;
        break;
      case 'questDataList':
        questDataList = data;
        break;
      case 'isBonusQuestComplete' :
        isBonusQuestComplete = data;
        break;
      default:
        break;
    }
  }

  void addQuestData( QuestData newQuestData ){
    questDataList.add( newQuestData );
  }

}

class QuestData {
  int questPoint = 0;
  String questName = '';
  bool isCompleted;

  void createQuestData( [ String qn, int qp, bool ic ] ){
    questName = qn;
    questPoint = qp;
    isCompleted = ic;
  }

  void updateQuestData( String key, dynamic data ){
    switch( key ){
      case 'questPoint' :
        questPoint = data;
        break;
      case 'questName' :
        questName = data;
        break;
      case 'isCompleted' :
        isCompleted = data;
        break;
      default :
        break;
    }
  }

}


class QuestDatabase {
  final List<List<dynamic>> questDatabase = [
    [ 103, '24時間チャレンジ1' ,'24h Challenge 103 pt' ],
    [ 186, '24時間チャレンジ2' ,'24h Challenge 186 pt' ],
    [ 269, '24時間チャレンジ3' ,'24h Challenge 269 pt' ],
    [ 107, 'Lv19+マター2個' ,'Get 2 Lv 19+ Dark Essences' ],
    [ 154, 'Lv19+マター4個' ,'Get 4 Lv 19+ Dark Essences' ],
    [ 201, 'Lv19+マター6個' ,'Get 5 Lv 19+ Dark Essences' ],
    [ 101, 'ギルコ消費500K' ,'Spend Guild Coins 500K' ],
    [ 138, 'ギルコ消費1M' ,'Spend Guild Coins 1M' ],
    [ 117, 'レジェンドボックス1' ,'Obtain 1 [Legendary] Loot' ],
    [ 154, 'レジェンドボックス2' ,'Obtain 2 [Legendary] Loot' ],
    [ 191, 'レジェンドボックス3' ,'Obtain 3 [Legendary] Loot' ],
    [ 228, 'レジェンドボックス4' ,'Obtain 4 [Legendary] Loot' ],
    [ 106, 'ギルドミッション120' ,'Complete Guild Quests 120 times' ],
    [ 102, 'ギルドミッション150' ,'Complete Guild Quests 150 times' ],
    [ 112, 'ギルドミッション170' ,'Complete Guild Quests 170 times' ],
    [ 105, 'ゴールド供給' ,'Supply Gold' ],
    [ 115, 'ゴールド115' ,'Gather Gold 115pt' ],
    [ 143, 'ゴールド143' ,'Gather Gold 143pt' ],
    [ 127, 'ゴールド127' ,'Gather Gold 127pt' ],
    [ 144, 'ゴールド144' ,'Gather Gold 144pt' ],
    [ 161, 'ゴールド161' ,'Gather Gold 161pt' ],
    [ 178, 'ゴールド178' ,'Gather Gold 178pt' ],
    [ 111, 'コロシアム挑戦' ,'Colosseum Battles' ],
    [ 102, 'コロシアムランキング' ,'Colosseum Rank Up' ],
    [ 110, 'ジェム消費25K' ,'Spend Gems 25K' ],
    [ 141, 'ジェム消費50K' ,'Spend Gems 50K' ],
    [ 105, '核精製1' ,'Merge 1 Skill stones' ],
    [ 128, '核精製2' ,'Merge 2 Skill stones' ],
    [ 152, '核精製3' ,'Merge 3 Skill stones' ],
    [ 119, 'スペシャルパック2' ,'Purchase Special Bundles 2 times' ],
    [ 100, 'スペシャルパック3' ,'Purchase Special Bundles 3 times' ],
    [ 116, 'スペシャルパック5' ,'Purchase Special Bundles 5 times' ],
    [ 133, 'スペシャルパック7' ,'Purchase Special Bundles 7 times' ],
    [ 149, 'スペシャルパック9' ,'Purchase Special Bundles 9 times' ],
    [ 157, 'スペシャルパック10' ,'Purchase Special Bundles 10 times' ],
    [ 198, 'スペシャルパック15' ,'Purchase Special Bundles 15 times' ],
    [ 206, 'ソロ10位1回' ,'Rank Top 10 in Solo Events 1 time' ],
    [ 302, 'ソロ10位2回' ,'Rank Top 10 in Solo Events 2 times' ],
    [ 112, 'ソロ70位1回' ,'Solo quest ranking 70th 1 time' ],
    [ 143, 'ソロ70位2回' ,'Solo quest ranking 70th 2 times' ],
    [ 147, 'ソロ70位3回' ,'Solo quest ranking 70th 3 times' ],
    [ 206, 'ソロ70位4回' ,'Solo quest ranking 70th 4 times' ],
    [ 269, 'ソロ70位6回' ,'Solo quest ranking 70th 6 times' ],
    [ 147, 'ソロランク3 8回' ,'Solo Events Phase 3 complete 8 times' ],
    [ 104, 'ダークマター獲得4' ,'Get Dark Essences 4 times' ],
    [ 134, 'ダークマター獲得6' ,'Get Dark Essences 6 times' ],
    [ 100, 'パワーアップ100' ,'Increase total Might 100pt' ],
    [ 147, 'パワーアップ147' ,'Increase total Might 147pt' ],
    [ 145, 'ヒーロー育成パワーアップ' ,'Increase Might (Hero Armies)' ],
    [ 106, 'ミッションクリアパワーアップ106' ,'Increase Might (Quests) 106pt' ],
    [ 144, 'ミッションクリアパワーアップ144' ,'Increase Might (Quests) 144pt' ],
    [ 100, '研究パワーアップ100' ,'Increase Might (Research) 100pt' ],
    [ 147, '研究パワーアップ147' ,'Increase Might (Research) 147pt' ],
    [ 133, '建設パワーアップ133' ,'Increase Might (Buildings) 133pt' ],
    [ 100, '訓練パワーアップ100' ,'Increase Might (Troops) 100pt' ],
    [ 147, '訓練パワーアップ147' ,'Increase Might (Troops) 147pt' ],
    [ 118, 'ホーリースター消費30K' ,'Use Holy Stars 30K' ],
    [ 149, 'ホーリースター消費50K' ,'Use Holy Stars 50K' ],
    [ 106, 'ヘルプ40回' ,'Send help to your guild mates 40 times' ],
    [ 137, 'ヘルプ120回' ,'Send help to your guild mates 120 times' ],
    [ 101, 'ラッキーコイン消費25' ,'Spend 25 Luck Tokens' ],
    [ 112, 'ラッキーコイン消費45' ,'Spend 45 Luck Tokens' ],
    [ 135, 'ラッキーコイン消費70' ,'Spend 70 Luck Tokens' ],
    [ 130, 'すごろく2' ,'Kingdom Tycoon 2' ],
    [ 155, 'すごろく4' ,'Kingdom TycoonL 4' ],
    [ 171, 'すごろく6' ,'Kingdom Tycoon 6' ],
    [ 214, 'すごろく8' ,'Kingdom Tycoon 8' ],
    [ 145, 'ランダム145' ,'Get a random quest 145pt' ],
    [ 185, 'ランダム185' ,'Get a random quest 185pt' ],
    [ 225, 'ランダム225' ,'Get a random quest 225pt' ],
    [ 265, 'ランダム265' ,'Get a random quest 265pt' ],
    [ 102, 'ロード処刑3' ,'Execute Prisoners 3 times' ],
    [ 116, 'ロード処刑5' ,'Execute Prisoners 5 times' ],
    [ 152, 'ロード処刑10' ,'Execute Prisoners 10 times' ],
    [ 189, 'ロード処刑15' ,'Execute Prisoners 15 times' ],
    [ 137, '外装強化137' ,'Unlock Castle Stars 137pt' ],
    [ 155, '外装強化155' ,'Unlock Castle Stars 155pt' ],
    [ 174, '外装強化174' ,'Unlock Castle Stars 174pt' ],
    [ 211, '外装強化211' ,'Unlock Castle Stars 211pt' ],
    [ 109, '技術研究10' ,'Research Tech 10 items' ],
    [ 128, '技術研究15' ,'Research Tech 15 items' ],
    [ 148, '技術研究20' ,'Research Tech 20 items' ],
    [ 171, '技術研究26' ,'Research Tech 26 items' ],
    [ 106, '行政ミッション120' ,'Complete Admin Quests 120' ],
    [ 102, '行政ミッション150' ,'Complete Admin Quests 150' ],
    [ 112, '行政ミッション170' ,'Complete Admin Quests 170' ],
    [ 105, '鉱石供給' ,'Supply Ore' ],
    [ 115, '鉱石採取115' ,'Gather Ore 115pt' ],
    [ 143, '鉱石採取143' ,'Gather Ore 143pt' ],
    [ 127, '鉱石採取127' ,'Gather Ore 127pt' ],
    [ 144, '鉱石採取144' ,'Gather Ore 144pt' ],
    [ 161, '鉱石採取161' ,'Gather Ore 161pt' ],
    [ 178, '鉱石採取178' ,'Gather Ore 178pt' ],
    [ 101, '時短消費10d' ,'Time Reduced Using Speed Ups 10d' ],
    [ 131, '時短消費16d' ,'Time Reduced Using Speed Ups 16d' ],
    [ 130, '精製時短10d' ,'Time reduced using Speed Up Merging 10d' ],
    [ 156, '精製時短16d' ,'Time reduced using Speed Up Merging 16d' ],
    [ 110, '資源供給' ,'Supply Resources' ],
    [ 122, '資源122' ,'Gather Resources 122pt' ],
    [ 127, '資源採取127' ,'Gather Resources 127pt' ],
    [ 144, '資源採取144' ,'Gather Resources 144pt' ],
    [ 152, '資源採取152' ,'Gather Resources 152pt' ],
    [ 161, '資源採取161' ,'Gather Resources 161pt' ],
    [ 178, '資源採取178' ,'Gather Resources 178pt' ],
    [ 117, '指揮官4' ,'Win Dark Nest Coalition battles (Rally Captain only) 4 times' ],
    [ 153, '指揮官6' ,'Win Dark Nest Coalition battles (Rally Captain only) 6 times' ],
    [ 121, '召喚の書 精製50' ,'Merge Pacts 50' ],
    [ 151, '召喚の書 精製100' ,'Merge Pacts 100' ],
    [ 115, '召喚攻撃115' ,'Use Familiar Attack skills 115pt' ],
    [ 137, '召喚攻撃137' ,'Use Familiar Attack skills 137pt' ],
    [ 160, '召喚攻撃160' ,'Use Familiar Attack skills 160pt' ],
    [ 102, '商船8' ,'Cargo Ship 8 times' ],
    [ 117, '商船20' ,'Cargo Ship 20 times' ],
    [ 149, '商船24' ,'Cargo Ship 24 times' ],
    [ 146, '商船32' ,'Cargo Ship 32 times' ],
    [ 156, '商船36' ,'Cargo Ship 36 times' ],
    [ 166, '商船40' ,'Cargo Ship 40 times' ],
    [ 176, '商船44' ,'Cargo Ship 44 times' ],
    [ 105, '食糧供給' ,'Supply Food' ],
    [ 115, '食糧採取115' ,'Gather Food 115pt' ],
    [ 127, '食糧採取127' ,'Gather Food 127pt' ],
    [ 144, '食糧採取144' ,'Gather Food 144pt' ],
    [ 161, '食糧採取161' ,'Gather Food 161pt' ],
    [ 178, '食糧採取178' ,'Gather Food 178pt' ],
    [ 139, '神秘な宝箱20' ,'Open Mystery Boxes 20 times' ],
    [ 126, '神秘な宝箱35' ,'Open Mystery Boxes 35 times' ],
    [ 139, '神秘な宝箱40 3d' ,'Open 40 Mystery Boxes in 3 days' ],
    [ 139, '神秘な宝箱40 4d' ,'Open 40 Mystery Boxes in 4 days' ],
    [ 152, '神秘な宝箱45' ,'Open Mystery Boxes 45 times' ],
    [ 105, '石材供給' ,'Supply Stone' ],
    [ 115, '石材採取115' ,'Gather Stone 115pt' ],
    [ 143, '石材採取143' ,'Gather Stone 143pt' ],
    [ 127, '石材採取127' ,'Gather Stone 127pt' ],
    [ 144, '石材採取144' ,'Gather Stone 144pt' ],
    [ 161, '石材採取161' ,'Gather Stone 161pt' ],
    [ 178, '石材採取178' ,'Gather Stone 178pt' ],
    [ 117, 'Tier4死亡117' ,'Lose Tier 4 Troops (killed in battle) 117pt' ],
    [ 133, 'Tier4死亡133' ,'Lose Tier 4 Troops (killed in battle) 133pt' ],
    [ 179, 'Tier4死亡179' ,'Lose Tier 4 Troops (killed in battle) 179pt' ],
    [ 233, 'Tier4死亡233' ,'Lose Tier 4 Troops (killed in battle) 233pt' ],
    [ 187, '地獄10位1回' ,'Rank Top 10 in Hell Events 1 time' ],
    [ 290, '地獄10位2回' ,'Rank Top 10 in Hell Events 2 time' ],
    [ 111, '地獄70位1回' ,'Rank in Top 70 for Hell Events 1 time' ],
    [ 143, '地獄70位2回' ,'Rank in Top 70 for Hell Events 2 time' ],
    [ 206, '地獄70位4回' ,'Rank in Top 70 for Hell Events 4 time' ],
    [ 300, '地獄70位7回' ,'Rank in Top 70 for Hell Events 7 time' ],
    [ 105, '地獄ランク3 1回' ,'Hell Events Phase 3 complete 1time' ],
    [ 118, '地獄ランク3 3回 118' ,'Hell Events Phase 3 complete 3 times 118pt' ],
    [ 169, '地獄ランク3 3回 169' ,'Hell Events Phase 3 complete 3 times 169pt' ],
    [ 140, '地獄ランク3 4回 140' ,'Hell Events Phase 3 complete 4 times 140pt' ],
    [ 141, '地獄ランク3 4回 141' ,'Hell Events Phase 3 complete 4 times 141pt' ],
    [ 242, '地獄ランク3 5回' ,'Hell Events Phase 3 complete 5 times' ],
    [ 189, '地獄ランク3 6回' ,'Hell Events Phase 3 complete 6 times' ],
    [ 207, '地獄ランク3 7回 207' ,'Hell Events Phase 3 complete 7 times 207pt' ],
    [ 213, '地獄ランク3 7回 213' ,'Hell Events Phase 3 complete 7 times 213pt' ],
    [ 352, '地獄ランク3 8回' ,'Hell Events Phase 3 complete 8 times' ],
    [ 252, '地獄ランク3 9回' ,'Hell Events Phase 3 complete 9 times' ],
    [ 285, '地獄ランク3 10回' ,'Hell Events Phase 3 complete 10 times' ],
    [ 320, '地獄ランク3 12回' ,'Hell Events Phase 3 complete 12 times' ],
    [ 135, '調教石400' ,'Use Fragments 400' ],
    [ 158, '調教石600' ,'Use Fragments 600' ],
    [ 127, '秘薬/神薬 5100EXP 127' ,'Gain Familiar EXP with EXP items 5100EXP 127pt' ],
    [ 127, '秘薬/神薬 10200EXP 127' ,'Gain Familiar EXP with EXP items 10200EXP 127pt' ],
    [ 140, '秘薬/神薬 140' ,'Gain Familiar EXP with EXP items 140pt' ],
    [ 170, '秘薬/神薬 170' ,'Gain Familiar EXP with EXP items 170pt' ],
    [ 103, '治療' ,'Heal Wounded Soldiers' ],
    [ 115, '訓練' ,'Train Soldiers' ],
    [ 112, '冒険モード' ,'Complete Hero Stages' ],
    [ 113, '魔獣80' ,'Hit Monsters 80 times' ],
    [ 121, '魔獣90' ,'Hit Monsters 90 times' ],
    [ 163, '魔獣140' ,'Hit Monsters 140 times' ],
    [ 126, '魔獣迷宮レア魔獣1' ,'Meet a Gemming Gremlin in Kingdom Tycoon 1 time' ],
    [ 168, '魔獣迷宮レア魔獣2' ,'Meet a Gemming Gremlin in Kingdom Tycoon 2 times' ],
    [ 209, '魔獣迷宮レア魔獣3' ,'Meet a Gemming Gremlin in Kingdom Tycoon 3 times' ],
    [ 136, '魔獣迷宮エリートレア魔獣1 136' ,'Encounter Elite-Labyrinth Guardians 1 time 136pt' ],
    [ 150, '魔獣迷宮エリートレア魔獣1 150' ,'Encounter Elite-Labyrinth Guardians 1 time 150pt' ],
    [ 206, '魔獣迷宮エリートレア魔獣2' ,'Encounter Elite-Labyrinth Guardians 2 times' ],
    [ 275, '魔獣迷宮エリートレア魔獣3' ,'Encounter Elite-Labyrinth Guardians 3 times' ],
    [ 107, 'Lv5採取1' ,'Clear a full Lv 5 Resource Tile 1 time' ],
    [ 124, 'Lv5採取2' ,'Clear a full Lv 5 Resource Tile 2 times' ],
    [ 141, 'Lv5採取3' ,'Clear a full Lv 5 Resource Tile 3 times' ],
    [ 175, 'Lv5採取5' ,'Clear a full Lv 5 Resource Tile 5 times' ],
    [ 105, '木材供給' ,'Supply Timber' ],
    [ 115, '木材採取115' ,'Gather Timber 115pt' ],
    [ 143, '木材採取143' ,'Gather Timber 143pt' ],
    [ 127, '木材採取127' ,'Gather Timber 127pt' ],
    [ 144, '木材採取144' ,'Gather Timber 144pt' ],
    [ 161, '木材採取161' ,'Gather Timber 161pt' ],
    [ 178, '木材採取178' ,'Gather Timber 178pt' ],
  ];
}

class BonusQuestDatabase {
  final List<List<String>> bonusQuestDatabase = [
    [ '24時間チャレンジ3回', 'Complete 24h Challenge Quests 3 times' ],
    [ '150pt以上クエスト6個', 'Complete 6 Quests that are worth more than 150 pt' ],
    [ '最初24hクエスト6個', 'Complete 6 Quests on the first day' ],
    [ '最後24hクエスト6個', 'Complete 6 Quests on the last day' ],
    [ 'ギルドコイン消費3.6M', 'Spend Guild Coins 3.6M' ],
    [ 'スペシャルパック4回', 'Complete 4 Special Bundle Quests' ],
    [ 'パワーアップ25M治療以外', 'Increase total Might 25M' ],
    [ '研究パワーアップ12M', 'Increase Might (Research) 12M' ],
    [ '訓練パワーアップ24M', 'Increase Might (Troops) 24M' ],
    [ 'ホーリースター消費250K', 'Use Holy Stars 250K' ],
    [ '巣窟クエスト6回', 'Complete Dark Nest related Quests 6 times' ],
    [ 'ラッキーコイン消費400', 'Spend 400 Luck Tokens' ],
    [ 'ランダムクエスト3回', 'Complete 3 random Quests' ],
    [ 'ジェムグレムリン5回', 'Encounter Gemming Gremlin 5 times' ],
    [ '資源採取150M', 'Gathering Resources 150M' ],
    [ '商船交換3回', 'Cargo Ship quest 3 times' ],
    [ '神秘な宝箱135回', 'Open Mystery Boxes 135 times' ],
    [ '地獄クエスト5回', 'Complete Hell Event 5 Quests' ],
    [ '魔獣クエスト5回', 'Complete 5 Labyrinth Guardian Quests' ],
  ];
}