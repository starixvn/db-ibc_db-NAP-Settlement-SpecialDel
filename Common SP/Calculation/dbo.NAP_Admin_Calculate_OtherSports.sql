/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_OtherSports]
	@matchid						INT
	,@action						VARCHAR(20)		= 'CAL'
	,@strTransIds					VARCHAR(MAX)	= NULL
	,@CalledByBrokerService			BIT				= 0
AS
/*
	Created: 20181016@Vicky
	Task : Covered SP for othersports settlement
	DB: EXECREP SP (DBTrans_Bet)

	Revisions:
		

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @isUndo BIT

	SET @isUndo = CASE WHEN @action LIKE '%UNDO%' THEN 1
					   ELSE 0
				  END

	IF @@SERVERNAME IN ('DB042', 'SITDB042', 'DB232\SQLSERVER2008R2', 'DB233\SQLSERVER2008R2' ) AND @isUndo = 0
		RETURN


	IF @action LIKE 'CAL%'
		EXEC dbo.NAP_Admin_Calculate_TransID
			  @transIds   		= @strTransIds

	IF @action LIKE 'REFUND%'
		EXEC dbo.NAP_Admin_Calculate_Refund_TransID
			   @transIds   		= @strTransIds
			  
	IF @action LIKE 'UNDO%'
		EXEC dbo.NAP_Admin_Calculate_Undo_TransID
			   @transIds   		= @strTransIds
END
GO