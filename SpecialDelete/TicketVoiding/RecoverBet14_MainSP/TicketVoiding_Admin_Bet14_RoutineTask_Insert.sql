/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Admin_Bet14_RoutineTask_Insert](@AffectedList VARCHAR(MAX))
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		
	Param's Explanation:  
	
	DECLARE @AffectedList VARCHAR(MAX), @xml XML
	SET @AffectedList = '<root>
						   <r c="2" st="100" ast="100" w="2019-06-14" w_dif="0.12" aw_dif="0.12" mw_dif="0.12" sw_dif="0.12" pc_dif="0.12" c_dif="0.12" ac_dif="0.12" sc_dif="0.12"/>
						   <r c="3" st="100" ast="100" w="2019-06-14" w_dif="0.12" aw_dif="0.12" mw_dif="0.12" sw_dif="0.12" pc_dif="0.12" c_dif="0.12" ac_dif="0.12" sc_dif="0.12"/>
						   <r c="3" st="100" ast="100" w="2019-06-15" w_dif="0.12" aw_dif="0.12" mw_dif="0.12" sw_dif="0.12" pc_dif="0.12" c_dif="0.12" ac_dif="0.12" sc_dif="0.12"/>
						</root>'

	SET @xml= CAST(@AffectedList as XML)

	SELECT r.value('@c','INT') AS CustID
		, r.value ('@w','SMALLDATETIME') AS winlostdate
		, r.value ('@w_dif','MONEY') AS winlost_dif
		, r.value ('@aw_dif','MONEY') AS awinlost_dif
		, r.value ('@mw_dif','MONEY') AS mwinlost_dif
		, r.value ('@sw_dif','MONEY') AS swinlost_dif
		, r.value ('@pc_dif','MONEY') AS playercomm_dif
		, r.value ('@c_dif','MONEY') AS comm_dif
		, r.value ('@ac_dif','MONEY') AS acomm_dif
		, r.value ('@sc_dif','MONEY') AS scomm_dif
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	   
*/
BEGIN
	
	SET NOCOUNT ON
	DECLARE @xml XML, @RequestID INT, @AffectedList_tmp VARCHAR(MAX)
	
	CREATE TABLE #Result_affectedList (custid INT, winlostdate SMALLDATETIME)
	
	SET @xml= CAST(@AffectedList AS XML)
	
	INSERT INTO #Result_affectedList (custid,winlostdate)
	SELECT r.value('@c','INT') AS CustID
		, r.value ('@w','SMALLDATETIME') AS winlostdate
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM #Result_affectedList)
		RETURN
		
	SET @RequestID = ISNULL((SELECT MAX(RequestID) 
							 FROM dbo.TicketVoiding_RoutineTasks WITH (NOLOCK)) + 1, 1)
	
	SET @AffectedList_tmp = (SELECT custid AS c, winlostdate AS w
							FROM #Result_affectedList 
							FOR XML RAW ('r'),ROOT('root')
							)
							
	INSERT INTO TicketVoiding_RoutineTasks (RequestID,StepNo, [Action], [Status], CreatedDate, AffectedList, ExecuteType)
	SELECT @RequestID, 1, 'Update sum_winloss', 0, GETDATE(),@AffectedList_tmp, 1
	UNION ALL
	SELECT @RequestID, 2, 'Update CS_Sum_winloss', 0, GETDATE(),@AffectedList_tmp, 1
	UNION ALL
	SELECT @RequestID, 3, 'Correct cn88 Headline Cash Balance', 0, GETDATE(),@AffectedList_tmp, 1
	UNION ALL
	SELECT @RequestID, 4, 'Correct data on rptStatement table', 0, GETDATE(),@AffectedList_tmp, 1
	UNION ALL
	SELECT @RequestID, 5, 'Adjust reset winning transaction & send mail', 0, GETDATE(),@AffectedList_tmp, 2
	UNION ALL
	SELECT @RequestID, 6, 're-gen summary reported tables', 0, GETDATE(),@AffectedList_tmp, 2
	UNION ALL
	SELECT @RequestID, 7, 'Fraud Sensor', 0, GETDATE(),@AffectedList_tmp, 2
	UNION ALL
	SELECT @RequestID, 8, 'TGRS', 0, GETDATE(),@AffectedList_tmp, 2
	
	DROP TABLE #Result_affectedList
		
END
GO