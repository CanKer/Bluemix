//
//  verPacientes.swift
//  SANA+
//
//  Created by Jorge Arturo César Martínez on 16/09/15.
//  Copyright © 2015 Jorge Arturo César Martínez. All rights reserved.
//

import UIKit

class verContactos: UIViewController, crearContactosDelegate, UITableViewDataSource, UITableViewDelegate {
//    class verPacientes: UITableViewController {
    
  
    var contactos: [String]?
    //var pacientes = ["Arturo", "Laura", "Carina"]

    
    override func viewDidLoad() {
        super.viewDidLoad()
        contactos = Array()
 //       busquedaPacientes.delegate = self
    }
    
    
 /*  func busquedaPacientes(busquedaPacientes: UISearchBar, textDidChange searchText: String) {
        
        filtered = data.filter({ (text) -> Bool in
            let tmp: NSString = text
            let range = tmp.rangeOfString(searchText, options: NSStringCompareOptions.CaseInsensitiveSearch)
            return range.location != NSNotFound
        })
        if(filtered.count == 0){
            searchActive = false;
        } else {
            searchActive = true;
        }
        self.tableView.reloadData()
    }

    */
    
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "handleRefresh:", forControlEvents: UIControlEvents.ValueChanged)
        
        return refreshControl
        }()
    
    
    @IBOutlet weak var tablaContactos: UITableView!
    @IBOutlet weak var busquedaContactos: UISearchBar!
    
    var busqueda : Bool = false
    var filto : [String] = []
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let identifier = segue.identifier
        if identifier == "crearContacto" {
            let crearContacto = segue.destinationViewController as! crearContactos
            crearContacto.delegate = self
        }
    }
    
    
    
    func crearContacto(nombre: String) {
        contactos!.append(nombre)
        print(contactos!.count)
        self.tablaContactos.reloadData()
        refreshControl.endRefreshing()
        
        
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print(contactos!.count)
        print("hola")
        return contactos!.count
        
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("cellID") as UITableViewCell?
        
        if cell == nil  {
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "cellID")
        }
        
        cell?.textLabel!.text = contactos![indexPath.row]
        return cell!
    }
    
  //  @IBAction func verDatos(nombre: String) {
       // pacientes = Pacientes
        
        
  //  }

    
}

