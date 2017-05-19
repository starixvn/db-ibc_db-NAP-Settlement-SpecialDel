ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_s213] 
	@strXML VARCHAR(MAX),
	@CalledByBrokerService BIT = 0 
AS
/*
	Created by:[Johnson]
	Date:[20160824]
	Task: Settlement for NG2
	DB: DBTXN/BODB02
	
	Revisions:
		- 20161214@Johnson: correct comm value [redmine:#68766]
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB06', 'DBTP', 'DB231', 'DB232','DB215','DB234','SITDB052', 'SITDB053', 'SITDB054', 'SITDB06' ,'DB231\DBSPU2' ,'DB232\DBSPU2') AND @CalledByBrokerService = 0
	BEGIN
		-- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
		DECLARE @sMessage NVARCHAR(MAX)

		SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_s213 '
		+'@strXML =' + '''' + @strXML + '''' + ','
		+'@CalledByBrokerService = 1'
		
		EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
			,@toService = N'//Service/Calculation_receive'
			,@onContract = N'//Contract/Calculation'
			,@messageType = N'//Message/Calculation'
			,@messageBody = @sMessage

		RETURN
	END
	ELSE
	BEGIN		
		CREATE TABLE #tmpTrans (transid BIGINT, payout MONEY)
		
		DECLARE @xml XML,
			@statusid TINYINT
		
		SET @xml = CONVERT(XML, N'<root><r t="' + REPLACE(REPLACE(@strXML, '|', '" p="'), ',', '"/><r t="') + '"/></root>')
		
		INSERT INTO #tmpTrans (transid, payout)
		SELECT T.C.value('./@t', 'bigint')
				,T.C.value('./@p', 'money')
		FROM @xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
		
		UPDATE b
		SET @statusid = statusid = CASE WHEN payout = stake THEN 111 --DRAW
										WHEN payout > stake THEN 112 --WON
										WHEN payout < stake THEN 113 --LOSE
										ELSE b.statusid	END,
			status = CASE WHEN @statusid = 111 THEN 'DRAW'
							WHEN @statusid = 112 THEN 'WON'
							WHEN @statusid = 113 THEN 'LOSE'
							ELSE status END,
			ruben = CASE WHEN @statusid IN (111,112,113) THEN 1 ELSE ruben END,
			WinLost = payout,
			aWinlost = (payout - stake)*-apositiontaking,
			mWinlost = (payout - stake)*-mpositiontaking,
			sWinlost = (payout - stake)*-spositiontaking,
			PlayerComm = CASE WHEN @statusid IN (112,113) THEN playerdiscount * stake ELSE 0 END,
			comm = CASE WHEN @statusid IN (112,113) THEN discount * stake * (1-apositiontaking) ELSE 0 END,
			acomm = CASE WHEN @statusid IN (112,113) THEN adiscount * stake * (1-(mpositiontaking+apositiontaking)) ELSE 0 END,
			scomm = CASE WHEN @statusid IN (112,113) THEN sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) ELSE 0 END			
		FROM bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTrans t ON b.transid = t.transid
		
		DROP TABLE #tmpTrans
	END	
	
	
END
GO