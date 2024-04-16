/*<info serverAlias="DBCTG-bodb02,DBACC-bodb02,DBAGE-bodb02,DBBOF-bodb02,DBTP-bodb02" executers="" isFunction="0"></info>*/

/*	
	Created: 20240416@Louisa
    Task: Create data test for SIT ONLY
    [Redmine:#202309,#200194]		
*/

---run on SIT only

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
VALUES (	63265390,1849463,1,'1628Bw7g2B78','B14*****443',0,5000.00,'RM' ,8
			,'2024-04-16 04:19:34.033'
			,'2024-04-16 04:19:34.033'
			,'2024-04-23 16:19:34.033'
			,NULL,1,0,NULL,25000.00,1,1,0,SYSDATETIME()
		)
		,(	63265390,19176837,1,'C0862c5cA166','SUP************00H',0,5000.00,'RM',8
			,'2024-04-16 04:19:34.033'
			,'2024-04-16 04:19:34.033'
			,'2024-04-23 16:19:34.033'
			,NULL,1,0,NULL,25000.00,1,1,0,SYSDATETIME()
		)
		,(	63265390,24976553,1,'9E009q1e94DF','Ssu********n04',0,5000.00,'RM',8
			,'2024-04-16 04:19:34.033'
			,'2024-04-16 04:19:34.033'
			,'2024-04-23 16:19:34.033'
			,NULL,1,0,NULL,25000.00,1,1,0,SYSDATETIME()
		)
		,(	63265390,24975019,1,'763D1h6qABA9','sup*******n02',0,5000.00,'RM',8
			,'2024-04-16 04:19:34.033'
			,'2024-04-16 04:19:34.033'
			,'2024-04-23 16:19:34.033'
			,NULL,1,0,NULL,25000.00,1,1,0,SYSDATETIME()
		)
		,(	63265390,19505699,1,'96Bo98AC55m4','SUP***********003',0,5000.00,'RM',8
			,'2024-04-16 04:19:34.033'
			,'2024-04-16 04:19:34.033'
			,'2024-04-23 16:19:34.033'
			,NULL,1,0,NULL,25000.00,1,1,0,SYSDATETIME()
		) 



















