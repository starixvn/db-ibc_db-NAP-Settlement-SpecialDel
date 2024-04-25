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
            SELECT 84725301 AS matchid,19176837 AS custid,1 AS TypeID,'FBz08E5EFhE4' AS VerificationCode
                ,'SUP*****00H' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'UUS' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-04-25 04:19:34.033' AS CreatedDate
                ,'2024-04-25 04:19:34.033' AS LastModifiedDate
                ,'2024-05-02 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-04-25 04:19:34.033' AS SettledDate,25000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
            UNION
            SELECT 84725301 AS matchid,19520130 AS custid,1 AS TypeID,'61DExC9BpB4E' AS VerificationCode
                ,'SUP*****005' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'UUS' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-04-25 04:19:34.033' AS CreatedDate
                ,'2024-04-25 04:19:34.033' AS LastModifiedDate
                ,'2024-05-02 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-04-25 04:19:34.033' AS SettledDate,25000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
            UNION
            SELECT 84725301 AS matchid,48635829 AS custid,1 AS TypeID,'7l724ACu87E2' AS VerificationCode
                ,'Sup*****003' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'UUS' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-04-25 04:19:34.033' AS CreatedDate
                ,'2024-04-25 04:19:34.033' AS LastModifiedDate
                ,'2024-05-02 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-04-25 04:19:34.033' AS SettledDate,25000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
            UNION
            SELECT 84725301 AS matchid,48635840 AS custid,1 AS TypeID,'9164dD5b7BB4' AS VerificationCode
                ,'Sup*****009' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'UUS' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-04-25 04:19:34.033' AS CreatedDate
                ,'2024-04-25 04:19:34.033' AS LastModifiedDate
                ,'2024-05-02 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-04-25 04:19:34.033' AS SettledDate,25000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
            UNION
            SELECT 84725301 AS matchid,48635861 AS custid,1 AS TypeID,'5dEC41p900D0' AS VerificationCode
                ,'Sup*****00P' AS DisplayName,0 AS StatusID,5000.00 AS Payout,'UUS' AS Currency
                ,8 AS LastModifiedUserID
                ,'2024-04-25 04:19:34.033' AS CreatedDate
                ,'2024-04-25 04:19:34.033' AS LastModifiedDate
                ,'2024-05-02 04:19:34.033' AS ExpiredDate
                ,NULL AS NotifiedDate,1 AS IsTest,0 AS IsLicensee,'2024-04-25 04:19:34.033' AS SettledDate,25000.00 AS PoolPrize
                ,0 AS finalhomescore,0 AS finalawayscore,0 AS IsNotify,SYSDATETIME() AS RepUpdateTime
) AS tbl


















