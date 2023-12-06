pragma solidity ^0.8.13;


contract TicketingSystem {

    struct Artist{
        bytes32 name;
        uint256 categorie;
        address owner;
        uint256 totalTicketSold;
    }

    struct Venue{
        bytes32 name;
        uint256 capacity;
        uint256 venueCommission;
        address payable owner;
    }

    struct Concert{
        uint256 artistId;
        uint256 venueId;
        uint256 concertDate;
        uint256 ticketPrice;
        bool validatedByArtist;
        bool validatedByVenue;
        uint totalTicketSold;
        uint totalMoneyCollected;
    }

    struct Ticket{
        uint256 concertId;
        address payable owner;
        bool isAvailable;
        bool isAvailableForSale;
        uint256 amountPaid;
    }

    uint256 public artistCount = 0;
    uint256 public venueCount = 0;
    uint256 public concertCount = 0;
    uint256 public ticketCount = 0;

    //MAPPINGS & ARRAYS
    mapping(uint256 => Artist) public artistsRegister;
    mapping(bytes32 => uint256) private artistsId;

    mapping(uint256 => Venue) public venuesRegister;
    mapping(bytes32 => uint256) private venuesId;

    mapping(uint256 => Concert) public concertsRegister;
    mapping(bytes32 => uint256) private concertsId;

    mapping(uint256 => Ticket) public ticketsRegister;
    mapping(bytes32 => uint256) private ticketsId;

    function createArtist(bytes32 _name, uint256 _artistCategory) public {
        require(bytes32(_name).length > 0, "Artist name cannot be empty");
        artistCount++;
        artistsRegister[artistCount] = Artist(_name, _artistCategory,msg.sender, 0);
        artistsId[_name] = artistCount;
    }

    function modifyArtist(uint256 _artistId, bytes32 _name, uint256 _artistCategory, address payable _newOwner) public{
        require(msg.sender == artistsRegister[_artistId].owner, "not the owner");
        artistsRegister[_artistId].name = _name;
        artistsRegister[_artistId].categorie = _artistCategory;
        artistsRegister[_artistId].owner = _newOwner;
    }

    function createVenue(bytes32 venueName, uint256 capacity, uint256 venueCommission) public{
        require(bytes32(venueName).length > 0, "Venue name cannot be empty");
        venueCount++;
        venuesRegister[venueCount] = Venue(venueName, capacity, venueCommission, payable(msg.sender));
        venuesId[venueName] = venueCount;
    }

    function modifyVenue(uint256 venueId, bytes32 venueName, uint256 capacity, uint256 venueCommission, address payable newOwner) public{
        require(msg.sender == venuesRegister[venueId].owner, "not the venue owner");
        venuesRegister[venueId].name = venueName;
        venuesRegister[venueId].capacity = capacity;
        venuesRegister[venueId].venueCommission = venueCommission;
        venuesRegister[venueId].owner = newOwner;
    }

    function createConcert(uint256 _artistId, uint256 _venueId, uint256 _concertDate, uint256 _ticketPrice) public {
        concertCount++;
        concertsRegister[concertCount] = Concert(_artistId, _venueId, _concertDate, _ticketPrice, false, false, 0, 0);
        if (artistsRegister[_artistId].owner == msg.sender) concertsRegister[concertCount].validatedByArtist = true;
    }   

    function validateConcert(uint256 _concertId) public {
        require(
        msg.sender == artistsRegister[concertsRegister[_concertId].artistId].owner ||
        msg.sender == venuesRegister[concertsRegister[_concertId].venueId].owner,
        "Not authorized to validate concert");
        if (msg.sender == artistsRegister[concertsRegister[_concertId].artistId].owner) {
            concertsRegister[_concertId].validatedByArtist = true;
        } 
        else {
            concertsRegister[_concertId].validatedByVenue = true;
        }
    }

    function emitTicket(uint256 _concertId, address payable _ticketOwner) public {
        require(msg.sender == artistsRegister[concertsRegister[_concertId].artistId].owner, "not the owner");
        ticketCount++;
        ticketsRegister[ticketCount] = Ticket(_concertId, _ticketOwner, true, false, 0);
        concertsRegister[_concertId].totalTicketSold++;
    }

    function useTicket(uint256 _ticketId) public {
        require(msg.sender == ticketsRegister[_ticketId].owner, "sender should be the owner");
        require(block.timestamp+60*60*24 >= concertsRegister[ticketsRegister[_ticketId].concertId].concertDate, "should be used the d-day");
        require(concertsRegister[ticketsRegister[_ticketId].concertId].validatedByVenue, "should be validated by the venue");
        ticketsRegister[_ticketId].isAvailable = false;
        ticketsRegister[_ticketId].owner = payable(address(0));
    }

    function buyTicket(uint _concertId) public payable {
        ticketCount++;
        ticketsRegister[ticketCount] = Ticket(_concertId, payable(msg.sender), true, false, msg.value);
        concertsRegister[_concertId].totalTicketSold++;
        concertsRegister[_concertId].totalMoneyCollected += msg.value;
    }

    function transferTicket(uint _ticketId, address payable _newOwner) public{
        require(msg.sender == ticketsRegister[_ticketId].owner, "not the ticket owner");
        ticketsRegister[_ticketId].owner = _newOwner;
    }

    function cashOutConcert(uint256 _concertId, address payable _cashOutAddress) public {
        require(block.timestamp >= concertsRegister[_concertId].concertDate,"should be after the concert");
        require(artistsRegister[concertsRegister[_concertId].artistId].owner == msg.sender, "should be the artist");
        
        uint256 totalTicketSales = concertsRegister[_concertId].ticketPrice * concertsRegister[_concertId].totalTicketSold;
        uint256 venueShare = (totalTicketSales * venuesRegister[concertsRegister[_concertId].venueId].venueCommission) / 10000;
        uint256 artistShare = totalTicketSales - venueShare;

        _cashOutAddress.call{value: artistShare}("");
        venuesRegister[concertsRegister[_concertId].venueId].owner.call{value: venueShare}("");

        artistsRegister[concertsRegister[_concertId].artistId].totalTicketSold += concertsRegister[_concertId].totalTicketSold;
    }

    
    function offerTicketForSale(uint _ticketId, uint _salePrice) public{
        require(msg.sender == ticketsRegister[_ticketId].owner, "should be the owner");
        require(_salePrice < ticketsRegister[_ticketId].amountPaid, "should be less than the amount paid");
        
        ticketsRegister[_ticketId].isAvailableForSale = true;
        ticketsRegister[_ticketId].amountPaid = _salePrice;

    }

    function buySecondHandTicket(uint256 _ticketId) public payable {
        Ticket storage ticketTemp = ticketsRegister[_ticketId];
        require(ticketTemp.isAvailable, "should be available");
        require(msg.value >= ticketTemp.amountPaid, "not enough funds");

        address payable previousOwner = ticketTemp.owner;
        ticketTemp.owner = payable(msg.sender);

        previousOwner.call{value: ticketTemp.amountPaid}("");

        ticketTemp.isAvailableForSale = false;
        ticketTemp.amountPaid =0;
    }



}