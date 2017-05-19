ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_180_Refund]
	@MatchId			INT
AS
/*	Creator: Kathy
	Date: 20150812
	Task: refund VS tickets (VS soccer, VS tennis)
	DB: DBTXN/BODB02
	
	Revisions:
	
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	WHILE 1 = 1
	BEGIN
		UPDATE TOP (10000) dbo.bettrans WITH (ROWLOCK, UPDLOCK)
			SET [status] = N'Refund'
				,statusID = 103
				,winlost = actual_stake
				,awinlost = 0
				,mwinlost = 0
				,swinlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,ruben = 1
				,statuswinlost = 0
		WHERE	matchid = @matchid
				AND statusID NOT IN (103, 101, 102) 
				AND bettype IN (1201, 1203, 1204, 1205, 1206, 1224, 1220, 1235, 1236)

		IF @@ROWCOUNT < 10000
			BREAK
	END
	
END

GO
GRANT VIEW DEFINITION ON [dbo].NAP_Admin_Calculate_VS_180_Refund TO [vnteam] AS [dbo]