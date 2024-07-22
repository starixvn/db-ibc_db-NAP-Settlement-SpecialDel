/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

-- correct winlostdate
UPDATE dbo.bettrans14 WITH(ROWLOCK, UPDLOCK)
	SET Winlostdate = '2024-07-16 00:00:00'
WHERE transid IN(277244537007505431,277249364550746116) 

GO

-- correct transfer
declare @jsondata varchar(max) = '[{"custid":120550192,"WinlostDate":"2024-07-16T00:00:00","winlost":200.6820,"AWinlost":6.5862,"MWinlost":0.0000,"SWinlost":0.0000,"PlayerComm":0.0000,"Comm":0.0000,"AComm":0.0000,"SComm":0.0000,"Stake":208.0000,"Actual_Stake":208.0000},{"custid":111750689,"WinlostDate":"2024-07-16T00:00:00","winlost":591.7840,"AWinlost":-42.5792,"MWinlost":0.0000,"SWinlost":0.0000,"PlayerComm":0.0000,"Comm":0.0000,"AComm":0.0000,"SComm":0.0000,"Stake":546.0000,"Actual_Stake":546.0000},{"custid":120550192,"WinlostDate":"2024-07-17T00:00:00","winlost":107.7130,"AWinlost":202.7583,"MWinlost":0.0000,"SWinlost":0.0000,"PlayerComm":0.0000,"Comm":0.0000,"AComm":0.0000,"SComm":0.0000,"Stake":333.0000,"Actual_Stake":333.0000},{"custid":111750689,"WinlostDate":"2024-07-17T00:00:00","winlost":397.4210,"AWinlost":117.7185,"MWinlost":0.0000,"SWinlost":0.0000,"PlayerComm":0.0000,"Comm":0.0000,"AComm":0.0000,"SComm":0.0000,"Stake":524.0000,"Actual_Stake":524.0000}]'

declare @tmpdata table (custid int, winlostdate smalldatetime, winlost money, awinlost money, mwinlost money, swinlost money
	,playercomm money, comm money, acomm money, scomm money, stake money, actual_Stake money)

insert into @tmpdata(custid, WinlostDate, winlost, AWinlost, MWinlost, SWinlost, PlayerComm, Comm, AComm, SComm, Stake, Actual_Stake)
SELECT custid, WinlostDate, winlost, AWinlost, MWinlost, SWinlost, PlayerComm, Comm, AComm, SComm, Stake, Actual_Stake
	FROM OPENJSON(@jsondata)
		WITH (
		custid int
		,WinlostDate  smalldatetime
		,winlost  MONEY
		,AWinlost  MONEY
		,MWinlost  MONEY
		,SWinlost  MONEY
		,PlayerComm  MONEY
		,Comm  MONEY
		,AComm  MONEY
		,SComm  MONEY
		,Stake  MONEY
		,Actual_Stake  MONEY
	)

UPDATE tf WITH(ROWLOCK, UPDLOCK)
	SET winlost = t.Winlost
		,AWinlost = t.AWinlost
		,MWinlost = t.MWinlost
		,SWinlost = t.SWinlost
		,PlayerComm = t.PlayerComm
		,Comm = t.Comm
		,AComm = t.AComm
		,SComm = t.SComm
		,Stake = t.Stake
		,Actual_Stake = t.Actual_Stake
FROM	dbo.Transfer tf
	INNER JOIN @tmpdata t
		ON	t.custid = tf.custid
			AND t.winlostdate = tf.winlostdate
			and tf.bettype = 19999