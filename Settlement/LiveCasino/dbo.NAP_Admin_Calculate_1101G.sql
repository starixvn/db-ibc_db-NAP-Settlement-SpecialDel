USE [bodb02]
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_1101G]
	@matchid	INT,
	@betteam	VARCHAR(100),
	@CommRate	MONEY ,
	@Bettype	SMALLINT	= 1101 
AS
/*
	Created by: Kathy
	Date: 20140224
	Task: Settlement 
	DB: DBTXN.BODB02

	Revisions:
		- 20150421@Kathy: Offer New Game Type "No Card Baccarat" (1106) [Redmine:#31630]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		
*/
SET NOCOUNT ON
BEGIN
	IF (@Bettype in (1101 ,1103, 1106)) 
		BEGIN			
			SET @betteam = REPLACE(@betteam,',','')

			DECLARE 
				@SettleA1	NVARCHAR(1),
				@SettleA2	NVARCHAR(1),
				@SettleA3	NVARCHAR(1),
				@SettleA4	NVARCHAR(1),
				@Draw		NVARCHAR(1),
				@StrLen		INT ,
				@modds money

			SELECT  @StrLen = LEN(@betteam)
			 
			SET @Draw = 0
			
			IF CHARINDEX('3',@betteam) >0
				BEGIN 
					SET @Draw = 1
				END

			IF (@StrLen = 1 )
				BEGIN
					SELECT @SettleA1= SUBSTRING(@betteam,1,1) 
				END
			IF (@StrLen = 2 )
				BEGIN
					SELECT @SettleA1= SUBSTRING(@betteam,1,1)  , @SettleA2 = SUBSTRING(@betteam,2,1) 
				END
			IF (@StrLen = 3 )
				BEGIN
					SELECT @SettleA1= SUBSTRING(@betteam,1,1)  , @SettleA2 = SUBSTRING(@betteam,2,1) , @SettleA3 = SUBSTRING(@betteam,3,1)  
				END
			IF (@StrLen = 4 )
				BEGIN
					SELECT @SettleA1= SUBSTRING(@betteam,1,1)  , @SettleA2 = SUBSTRING(@betteam,2,1) , @SettleA3 = SUBSTRING(@betteam,3,1)   , @SettleA4 = SUBSTRING(@betteam,4,1)
				END

			IF @@SERVERNAME not in ('DB042', 'DB043', 'DB044')
			BEGIN

				UPDATE dbo.bettransG with (ROWLOCK, UPDLOCK)
				SET @modds = 
						Case when @Draw = 1 
								Then Case when betteam in (@SettleA1,@SettleA2,@SettleA3,@SettleA4) then 1 --Win
												 when betteam in ('1','2') then 0  --Draw
												 else -1 --Lose
												 end 
								When @Draw = 0 Then Case when betteam in (@SettleA1,@SettleA2,@SettleA3,@SettleA4) then 1 --Win
												 Else -1 --Lose  
												 end  
								End ,
				WinLost = CASE
					WHEN betteam='1' and @modds >  0.25	THEN stake + stake * (case when odds<0 then 1 else odds end) * (1-@CommRate)
					WHEN @modds >  0.25	THEN stake + stake * (case when odds<0 then 1 else odds end)
					WHEN @modds =  0	THEN stake
					WHEN @modds < -0.25	THEN 0
					END,
				aWinLost = CASE
					WHEN betteam='1' and @modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking * (1-@CommRate)
					WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking
					WHEN @modds =  0	THEN 0
					WHEN @modds < -0.25	THEN stake * apositiontaking
					END,
				mWinLost = CASE
					WHEN betteam='1' and @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking * (1-@CommRate)
					WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking
					WHEN @modds =  0    	THEN 0
					WHEN @modds < -0.25 	THEN stake * mpositiontaking
					END,
				sWinLost = CASE
					WHEN betteam='1' and @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking * (1-@CommRate)
					WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking
					WHEN @modds =  0    	THEN 0
					WHEN @modds < -0.25 	THEN stake * spositiontaking
					END,
				playercomm	= CASE WHEN @modds <> 0 THEN stake*playerdiscount ELSE 0 END,
				comm		= CASE WHEN @modds <> 0 THEN discount*stake*(1-apositiontaking) ELSE 0 END,
				acomm		= CASE WHEN @modds <> 0 THEN adiscount*stake*(1-apositiontaking-mpositiontaking) ELSE 0 END,
				scomm		= CASE WHEN @modds <> 0 THEN sdiscount*stake*(1-apositiontaking-mpositiontaking-spositiontaking) ELSE 0 END,
				Status	= CASE
					WHEN @modds > 0 THEN N'WON'
					WHEN @modds = 0 THEN N'DRAW'
					WHEN @modds < 0 THEN N'LOSE'
					END,
				StatusID = CASE
					WHEN @modds > 0 THEN 112 --WON
					WHEN @modds = 0 THEN 111 --DRAW
					WHEN @modds < 0 THEN 113 --LOSE
					END,
				ruben=1

				WHERE
					matchid=@matchid AND
					--status NOT IN (N'VOID', N'REJECT')
					statusID NOT IN (101,102)


			END
		End


	IF (@Bettype in (1102,1104)) 
		Begin			
			Declare @Mapping TABLE ( RBetteam NVarchar(10) primary key)
			INSERT INTO @Mapping
			SELECT val FROM dbo.strSplit(@betteam, ',')

			IF @@SERVERNAME not in ('DB042', 'DB043', 'DB044')
			BEGIN

				UPDATE dbo.bettransG with (ROWLOCK, UPDLOCK)
				SET @modds = 
						Case when RBetteam is not null then 1 --Win
						else -1 --Lose
						End ,
				WinLost = CASE
					WHEN @modds >  0.25	THEN stake + stake * (case when odds<0 then 1 else odds end)
					WHEN @modds =  0	THEN stake
					WHEN @modds < -0.25	THEN 0
					END,
				aWinLost = CASE
					WHEN @modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking
					WHEN @modds =  0	THEN 0
					WHEN @modds < -0.25	THEN stake * apositiontaking
					END,
				mWinLost = CASE
					WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking
					WHEN @modds =  0    	THEN 0
					WHEN @modds < -0.25 	THEN stake * mpositiontaking
					END,
				sWinLost = CASE
					WHEN @modds >  0.25 	THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking
					WHEN @modds =  0    	THEN 0
					WHEN @modds < -0.25 	THEN stake * spositiontaking
					END,
				playercomm	= CASE WHEN @modds <> 0 THEN stake*playerdiscount ELSE 0 END,
				comm		= CASE WHEN @modds <> 0 THEN discount*stake*(1-apositiontaking) ELSE 0 END,
				acomm		= CASE WHEN @modds <> 0 THEN adiscount*stake*(1-apositiontaking-mpositiontaking) ELSE 0 END,
				scomm		= CASE WHEN @modds <> 0 THEN sdiscount*stake*(1-apositiontaking-mpositiontaking-spositiontaking) ELSE 0 END,
				Status	= CASE
					WHEN @modds > 0 THEN N'WON'
					WHEN @modds = 0 THEN N'DRAW'
					WHEN @modds < 0 THEN N'LOSE'
					END,
				StatusID = CASE
					WHEN @modds > 0 THEN 112 --WON
					WHEN @modds = 0 THEN 111 --DRAW
					WHEN @modds < 0 THEN 113 --LOSE
					END,
				ruben=1
				From bettransG left outer join @Mapping on Betteam = RBetteam
				WHERE
					matchid=@matchid AND
					--status NOT IN (N'VOID', N'REJECT')
					statusID NOT IN (101,102)

			END
		End
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Calculate_1101G] TO [Dot_Member] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_1101G] TO [vnteam] AS [dbo]