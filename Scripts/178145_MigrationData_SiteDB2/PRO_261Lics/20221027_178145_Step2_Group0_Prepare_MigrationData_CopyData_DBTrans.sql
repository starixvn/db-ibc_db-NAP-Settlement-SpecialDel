/*<info serverAlias="DBSIG-SiteDB02tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB02
    DB: DBCTG-SiteDB02tmp

	 Revisions:
		- 20220926@Victoria: SELECT data INTO new tables for CustDB.dbo.Customer [Redmineid:#178145] 
*/

USE SiteDB02tmp
GO

CREATE TABLE cust_20221006
(
	custid INT PRIMARY KEY
)

------------------------------------------------
INSERT INTO cust_20221006 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN	('18Luck','TGAA0813','XinliCV','Xinli2CV','YSYBO688','SKY1688','vnggame','368Cash','TT128','368CashSW','568Win','568WinSW','ab6688','ABEMT','Abcasino','Million','AG','AMG','PKbet','PanguGame','BETSUN','HuangMa','BigGaming','818Bet','HongChow','TangChao','CGame','SSSGaming','HCVIP','WinWin','BWGaming','CGame4','7kplatform','BGCV','SEAGaming','Aoncash','M8bola','Q8bola','NBCbet','Unobet','Winn69','Axiawin','Ratugg','Lagadewa','Monstergol','B24VN','Rio66','HAIFA','BBIN2','BBIN3','BE7','Luckywin88','beplay','beplayCV','DBP','Monaco','RBCV','Dawoo','pinbo','QUBO','DawooCV','Dawooxin','YYHbet','FB88','FB88CV','Happy1668','YAYOU','US8YAYOU','HC6YAYOU','J9YAYOU','Hejiyongle','Boma365','Hengcai88','GESAB','mansion88','Happy8','THECLUB','THEDEN','Mayayule','Dachen','MayFair','Vwin','MrCat','Fugui','TitanOne','VWIN66','WKCUR','WKPHIL','TitanCraft','Saibo','Titanbet','Mayibet','MayibetCV','OLE777','OLE777CV','Soon88','Soon88CV','TGO','365online','YBTech','BOSSB','YTX','Yunji','GAMEBee','SDY','dfbetCV','SDYSW','Entaplay','Tripleone','MICL','laba360','TSEnter','BSSB168','MYGAME','IgameTech','ARYA','MYGAMECV','BSSB168CV','TSXJCV','W88','GPIGAME','MAX88','ALPHA88','VN88','Win88','DF88','Asian88','ID88','BOG22','W88CV','ROYAL88','alog','zt828','Winbox','JDYGaming','V9betSW','PKKing','ug396','Baji','998bet','hjccasino','ITCbet','Callmeboss','HL8','9bet','WABET','VCBA','GMASTER','Gampag','bigbet','Peakk','Bolanation','Comebet','N8BK','3ge888','C7YOUXI','Gaobet','OSUSDT','VCBACV','Uwoniwin','383sport','USSBET','X33Asia','9w','LUCKYBET','kbosportCV','GoToWin','kbosports','ANGbet','TGXICV','Winsplay','GmasterS','YSYBO688CV','OBGM','9wtest','ABCGAME','ABCgamevip','AOGcasino','Apollo369','Asiasigma','AWS08','B8KRW','baowang188','Belegend','Bet88CV','Bigwiner','BoAPI09','BoAPI10','BoAPI11','C88bet','CandyA18','CCLive','CloudRock','CMBSW','d3sports','DCSDemo','DDwin','DemoCV','dghash','dghashCV','directapi','ECBet88','EclipseSW','FKsport','G4ALL','GLive','GMDFD','golden8','GsportsCV','Happistar','Heji888','HOHPLAY','HX9Candy','HY6','IvoryBet','JUYOU','kgsports','KingBet','LegendWin','lionsclub','luckybuy','M88ASIA','n88clubSW','NFBI','Nova88','OBsystem','oddstest','OGWLS','Opal88','opsl','opsl188','Ot88','PINT','PLAYES','QASite','Saba789','SabaDemo','SBObet','ScaleDemo1','SENBKK','skykey','Spondemo','SWDemo','SWSite','Tesla','Test0112','Test1607','TGXI','Twowin','TWWIN','TYM2','VEGA77','Vwin88','WBG88','Wcasino','Wcasino88','Webet88','WinboxSW','wmcasinoS','Xiaojin','Xinli3CV')