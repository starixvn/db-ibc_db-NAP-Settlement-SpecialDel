/*<info serverAlias="DBCTG-bodb02,DBACC-bodb02,DBAGE-bodb02,DBBOF-bodb02,DBTP-bodb02" executers="" isFunction="0"></info>*/

/*	
	Created: 20240416@Aries
    Task: Create data test for UAT ONLY
    [Redmine:#202309,#200194]		
*/


USE bodb02
GO

INSERT INTO LuckyDrawList
(	matchid
	,custid
	,TypeID
	,VerificationCode
	,DisplayName
	,StatusID
	,Payout
	,Currency 
	,LastModifiedUserID
	,CreatedDate
	,LastModifiedDate
	,ExpiredDate
	,NotifiedDate
	,IsTest
	,IsLicensee
	,SettledDate
	,PoolPrize
	,finalhomescore
	,finalawayscore
	,IsNotify
	,RepUpdateTime
)
SELECT matchid
	,custid
	,TypeID
	,VerificationCode
	,DisplayName
	,StatusID
	,Payout
	,Currency 
	,LastModifiedUserID
	,CreatedDate
	,LastModifiedDate
	,ExpiredDate
	,NotifiedDate
	,IsTest
	,IsLicensee
	,SettledDate
	,PoolPrize
	,finalhomescore
	,finalawayscore
	,IsNotify
	,RepUpdateTime FROM  (
            SELECT 85100519 AS matchid,48635829 AS custid,1 AS TypeID,'Fg2sD4C7D825' AS VerificationCode
                ,'Sup*****003' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'RM' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-05-02 04:19:34.033' AS CreatedDate
                ,'2024-05-02 04:19:34.033' AS LastModifiedDate
                ,'2024-05-09 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-05-02 04:19:34.033' AS SettledDate,20000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
            UNION
            SELECT 85100519 AS matchid,94163891 AS custid,1 AS TypeID,'Abo02E6DBD78' AS VerificationCode
                ,'SUP*****002' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'RM' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-05-02 04:19:34.033' AS CreatedDate
                ,'2024-05-02 04:19:34.033' AS LastModifiedDate
                ,'2024-05-09 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-05-02 04:19:34.033' AS SettledDate,20000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
            UNION
            SELECT 85100519 AS matchid,48427112 AS custid,1 AS TypeID,'f1B16m6EB5E9' AS VerificationCode
                ,'SUP*****001' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'RM' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-05-02 04:19:34.033' AS CreatedDate
                ,'2024-05-02 04:19:34.033' AS LastModifiedDate
                ,'2024-05-09 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-05-02 04:19:34.033' AS SettledDate,20000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
            UNION
            SELECT 85100519 AS matchid,22819157 AS custid,1 AS TypeID,'B45727B26tD9' AS VerificationCode
                ,'SUP*****010' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'RM' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-05-02 04:19:34.033' AS CreatedDate
                ,'2024-05-02 04:19:34.033' AS LastModifiedDate
                ,'2024-05-09 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-05-02 04:19:34.033' AS SettledDate,20000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
) AS tbl


















