//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Strings.sol";

contract RPS {
    
    
    
    constructor () payable {}
    
    /*
    event GameCreated(address originator, uint256 originator_bet);
    event GameJoined(address originator, address taker, uint256 originator_bet, uint256 taker_bet);
    event OriginatorWin(address originator, address taker, uint256 betAmount);
    event TakerWin(address originator, address taker, uint256 betAmount);
   */
   
    enum Hand {
        rock, paper, scissors, waiting
    }
    
    enum PlayerStatus{
        STATUS_WIN, STATUS_LOSE, STATUS_TIE, STATUS_PENDING
    }
    
    enum GameStatus {
        STATUS_NOT_STARTED, STATUS_STARTED, STATUS_COMPLETE, STATUS_ERROR
    }
    
    // player structure
    struct OriginatorPlayer {
        bytes32 handHash;
        Hand hand;
        address payable addr;
        PlayerStatus playerStatus;
        uint256 playerBetAmount;
    }
    struct TakerPlayer {
        Hand hand;
        address payable addr;
        PlayerStatus playerStatus;
        uint256 playerBetAmount;
    }
    
    struct Game {
        uint256 betAmount;
        GameStatus gameStatus;
        OriginatorPlayer originator;
        TakerPlayer taker;
        uint createdTime;
    }
    
    
    mapping(uint => Game) rooms;
    uint roomLen = 0;
    
    modifier isValidHand (Hand _hand) {
        require((_hand  == Hand.rock) || (_hand  == Hand.paper) || (_hand == Hand.scissors));
        _;
    }

    modifier isPlayer (uint roomNum, address sender) {
        require(sender == rooms[roomNum].originator.addr || sender == rooms[roomNum].taker.addr);
        _;
    }
    
    event GameCreated (address indexed originator, uint256 roomNum, uint256 betAmount );
    
    function createRoom (bytes32 _handHash) public payable returns (uint roomNum) {
        rooms[roomLen] = Game({
            betAmount: msg.value,
            gameStatus: GameStatus.STATUS_NOT_STARTED,
            originator: OriginatorPlayer({
                handHash: _handHash,
                hand: Hand.waiting,
                addr: payable(msg.sender),
                playerStatus: PlayerStatus.STATUS_PENDING,
                playerBetAmount: msg.value
            }),
            createdTime: block.timestamp,
            taker: TakerPlayer({ // will change
                hand: Hand.rock,
                addr: payable(msg.sender),  
                playerStatus: PlayerStatus.STATUS_PENDING,
                playerBetAmount: 0
            })
        });
        roomNum = roomLen;
        roomLen = roomLen+1;
        
        
        emit GameCreated(msg.sender, roomNum, msg.value);
    }
    
    function joinRoom(uint roomNum, Hand _hand) public payable isValidHand( _hand) {
       // Emit gameJoined(game.originator.addr, msg.sender, game.betAmount, msg.value);
        
        rooms[roomNum].taker = TakerPlayer({
            hand: _hand,
            addr: payable(msg.sender),
            playerStatus: PlayerStatus.STATUS_PENDING,
            playerBetAmount: msg.value
        });
        rooms[roomNum].betAmount = rooms[roomNum].betAmount + msg.value;
        // compareHands(roomNum);
    }

    modifier beforePayout(uint roomNum, Hand _hand, string memory _key, address sender) {
        // 1. 시간 계산
        // 함수를 하나 더만들어서 
        // 하루이내에 payout (만들고 하루이내 )
        uint currentTime = block.timestamp;
        if (currentTime > rooms[roomNum].createdTime + (60*60*24)) {
            // 정산이 하루 지났을 때 : taker 승리
            rooms[roomNum].originator.playerStatus = PlayerStatus.STATUS_LOSE;
            rooms[roomNum].taker.playerStatus = PlayerStatus.STATUS_WIN;
            _;
        }
        else{
            // 입력된 인자로 hash값을 만들어서 OriginatorPlayer의 hash 값이랑 비교후 맞으면 
            //  OriginatorPlayer의 hand 에 _hand 값을 입력
            // 보낸 사람이 originator인지 확인
            if(sender == rooms[roomNum].originator.addr){
                uint8 hand = uint8(_hand);
                bytes32 answer = keccak256(abi.encodePacked(Strings.toString(hand), _key));
                if(answer == rooms[roomNum].originator.handHash){
                    rooms[roomNum].originator.hand = _hand;
                    compareHands(roomNum);
                    _;
                }
            }
        }
    }

    
    function payout(uint roomNum, Hand _hand, string memory _key) public payable isPlayer(roomNum, msg.sender) beforePayout(roomNum, _hand,  _key, msg.sender) {
        // 키값을 받아서 originator 핸드를 할당해주고 나머지 연산 (beforePayout modifier)

        
        // 승패에 따라 정산
        if (rooms[roomNum].originator.playerStatus == PlayerStatus.STATUS_TIE && rooms[roomNum].taker.playerStatus == PlayerStatus.STATUS_TIE) {
            rooms[roomNum].originator.addr.transfer(rooms[roomNum].originator.playerBetAmount);
            rooms[roomNum].taker.addr.transfer(rooms[roomNum].taker.playerBetAmount);
        } else {
            if (rooms[roomNum].originator.playerStatus == PlayerStatus.STATUS_WIN) {
                rooms[roomNum].originator.addr.transfer(rooms[roomNum].betAmount);
            } else if (rooms[roomNum].taker.playerStatus == PlayerStatus.STATUS_WIN) {
                rooms[roomNum].taker.addr.transfer(rooms[roomNum].betAmount);
            } else {
                rooms[roomNum].originator.addr.transfer(rooms[roomNum].originator.playerBetAmount);
                rooms[roomNum].taker.addr.transfer(rooms[roomNum].taker.playerBetAmount);
            }
        }
         rooms[roomNum].gameStatus = GameStatus.STATUS_COMPLETE;
    }
    
    function compareHands(uint roomNum) private{
        uint8 originator = uint8(rooms[roomNum].originator.hand);
        uint8 taker = uint8(rooms[roomNum].taker.hand);
        
        rooms[roomNum].gameStatus = GameStatus.STATUS_STARTED;
        
        if (taker == originator){ //draw
            rooms[roomNum].originator.playerStatus = PlayerStatus.STATUS_TIE;
            rooms[roomNum].taker.playerStatus = PlayerStatus.STATUS_TIE;
            
        }
        else if ((taker +1) % 3 == originator) { // originator wins
            rooms[roomNum].originator.playerStatus = PlayerStatus.STATUS_WIN;
            rooms[roomNum].taker.playerStatus = PlayerStatus.STATUS_LOSE;
        }
        else if ((originator + 1)%3 == taker){
            rooms[roomNum].originator.playerStatus = PlayerStatus.STATUS_LOSE;
            rooms[roomNum].taker.playerStatus = PlayerStatus.STATUS_WIN;
        } else {
            rooms[roomNum].gameStatus = GameStatus.STATUS_ERROR;
        }
       
    }
}