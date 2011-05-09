Feature: Store and load data from multiple databases

  Background:
    Given the library works in development mode

  Scenario: two classes with two dbs
    Given the class space is cleared
    And a class Caveman inherits from Rod::Model
    And a class Caveman has a name field of type string
    And a class Caveman is connected to Database1
    And a class Automobile inherits from Rod::Model
    And a class Automobile has a name field of type string
    And a class Automobile is connected to Database2
    When Database1 is created
    And Database2 is created
    And I create a Caveman 
    And his name is 'Fred'
    And I store him in the database
    And I create an Automobile 
    And its name is 'Prehistoric'
    And I store him in the database
    And I reopen Database1 for reading
    And I reopen Database2 for reading
    Then there should be 1 Caveman
    And the name of the first Caveman should be 'Fred'
    And there should be 1 Automobile
    And the name of the first Automobile should be 'Prehistoric'
