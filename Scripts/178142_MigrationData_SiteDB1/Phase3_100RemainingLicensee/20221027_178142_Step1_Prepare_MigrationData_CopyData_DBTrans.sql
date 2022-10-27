/*<info serverAlias="DBSIG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Real Licensee
    DB: DBSIG-SiteDBtmp

	 Revisions:
		- 20220926@Victoria: SELECT data INTO new tables for CustDB.dbo.Customer [Redmineid:#178142] 
								
*/

USE SiteDBtmp
GO

CREATE TABLE cust_20221006
(
	custid INT PRIMARY KEY
)

------------------------------------------------
INSERT INTO cust_20221006 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('NLDSports','XmenSW','OCMSS','LIGAWLHKB','DTGJZ','TXJT','3star88','ECLBET','Mybet88','WINCLUB88','INSERTGAME','Alphalota','Barcelo9','Aladdin99','BVCLLC','Jiuyou','Yintai','Letian','WRServices','Xiaoxiang','YakaGaming','5ATech','IGSW','HBPT','TSLA','WRSeamless','TYgaming','KSTECH2','De365','UGaming','0sServices','ZhiFeng019','mbxusdt','GoldenF2','ZhiFeng173','UNOGAMING','ZTech','XLMEDIA','AEUGSW','24aviaCV','ACsports','FLCSW','GoldenFCV','HaHaGaming','HOroyal','IDNSPORT','IDNUPVND','JDJDAPI','JUNBOVN','KzingP88','KZSW','MultiSL88','OXPLAY','SGM88','STEBBCBI','TYgamingSW','WSlots','yuanbaoCV','ZF133FIN2','ZF215CNY','ZF267SW','ZF271SW','ZFRT155new','ZFRT159','ZFRT175','ZFRT179','ZFRT219','ZFRT240','ZFRT242','ZFRT259','ZFRT263','ZFRT80GPGT','ZhiFeng041','ZhiFeng050','ZhiFeng051','ZhiFeng094','ZhiFeng107','ZhiFeng116','ZhiFeng132','ZhiFeng168','ZhiFeng176','ZhiFeng200','ZhiFeng204','ZhiFeng221','ZhiFeng223','ZhiFeng228','ZhiFeng242','ZhiFeng248','ZhiFeng253','ZhiFeng255','ZhiFeng262','ZhiFeng266','ZhiFeng267','ZhiFeng271','ZhiFeng030','M18SW','ZFRT264','LG777','ZF138USD','ZhiFeng282')
